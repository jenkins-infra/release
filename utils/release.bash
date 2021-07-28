#!/bin/bash
set -euxo pipefail

function requireRepositoryPassword(){
  : "${MAVEN_REPOSITORY_PASSWORD:?Repository Password Missing}"
}

function requireGPGPassphrase(){
  : "${GPG_PASSPHRASE:?GPG Passphrase Required}" # Password must be the same for gpg agent and gpg key
}

function requireKeystorePass(){
  : "${SIGN_STOREPASS:?pass}"
}

function requireAzureKeyvaultCredentials(){
  : "${AZURE_VAULT_CLIENT_ID:? Require AZURE_VAULT_CLIENT_ID}"
  : "${AZURE_VAULT_CLIENT_SECRET:? Required AZURE_VAULT_CLIENT_SECRET}"
  : "${AZURE_VAULT_TENANT_ID:? Required AZURE_VAULT_TENANT_ID}"
}

function clean(){

    # Do not display transfer progress when downloading or uploading
    # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
    # mvn -s settings-release.xml -B --no-transfer-progress -Darguments=--no-transfer-progress release:clean
    # 2020-06-24: --no-transfer-progress doesn't seem to be fully suported in maven release plugin
    # This workaround can be reverted once MRELEASE-1048 is fixed
    # https://issues.apache.org/jira/browse/MRELEASE-1048

    mvn -s settings-release.xml -B --no-transfer-progress -Darguments=-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn release:clean
}

function cloneReleaseGitRepository(){
  # `ssh` is needed as git clone doesn't use GIT_SSH_COMMAND
  # https://git-scm.com/docs/git#Documentation/git.txt-codeGITSSHCOMMANDcode
  ssh -o StrictHostKeyChecking=no -T git@github.com || true
  git clone --branch "${RELEASE_GIT_BRANCH}" "${RELEASE_GIT_REPOSITORY}" .
}

function configureGit(){
  git checkout "${RELEASE_GIT_BRANCH}"
  git config --local user.email "${GIT_EMAIL}"
  git config --local user.name "${GIT_NAME}"
}

function configureGPG(){
  requireGPGPassphrase
  if ! gpg --fingerprint "${GPG_KEYNAME}"; then
    if [ ! -f "${GPG_FILE}" ]; then
      echo "${GPG_KEYNAME} or ${GPG_FILE} cannot be found"
      exit 1
    else
      gpg --list-keys
      if [ ! -f "$HOME/.gnupg/gpg.conf" ]; then touch "$HOME/.gnupg/gpg.conf"; fi
      if ! grep -E '^pinentry-mode loopback' "$HOME/.gnupg/gpg.conf"; then
        if grep -E '^pinentry-mode' "$HOME/.gnupg/gpg.conf"; then
          sed -i '/^pinentry-mode/d' "$HOME/.gnupg/gpg.conf"
        fi
        ## --pinenty-mode is needed to avoid gpg prompt during maven release
        echo 'pinentry-mode loopback' >> "$HOME/.gnupg/gpg.conf"
      fi
      gpg --import --batch "${GPG_FILE}"
    fi
  fi
}


function configureKeystore(){
  requireKeystorePass

  if [ ! -f "${SIGN_CERTIFICATE}" ]; then
      echo "${SIGN_CERTIFICATE} not found"
      exit 1
  fi

  case "$SIGN_CERTIFICATE" in
    *.pem )
      openssl pkcs12 -export \
        -out "$SIGN_KEYSTORE" \
        -in "${SIGN_CERTIFICATE}" \
        -password "pass:$SIGN_STOREPASS" \
        -name "$SIGN_ALIAS"
        ;;
    *.pfx )
      # pfx file download from azure key vault are not password protected, which is required for maven release plugin
      # so we need to add a new password
      openssl pkcs12 -in "${SIGN_CERTIFICATE}" -out tmpjenkins.pem -nodes -passin pass:""
      openssl pkcs12 -export \
        -out "$SIGN_KEYSTORE" \
        -in tmpjenkins.pem \
        -password "pass:$SIGN_STOREPASS" \
        -name "$SIGN_ALIAS"
      rm tmpjenkins.pem
      ;;
    *)
      echo "certificate file extension not support for ${SIGN_CERTIFICATE}"
      ;;
  esac
}

function azureAccountAuth(){
  az login --service-principal \
    -u "$AZURE_VAULT_CLIENT_ID" \
    -p "$AZURE_VAULT_CLIENT_SECRET" \
    -t "$AZURE_VAULT_TENANT_ID"
}

# Download Certificate from Azure KeyVault
function downloadAzureKeyvaultSecret(){
  requireAzureKeyvaultCredentials
  azureAccountAuth

  az keyvault secret download \
    --vault-name "$AZURE_VAULT_NAME" \
    --name "$AZURE_VAULT_CERT" \
    --encoding base64 \
    --file "$SIGN_CERTIFICATE"
}

# JENKINS_VERSION: Define which version will be package where:
# * \'latest\' means the latest version available
# * <version> represents any valid existing version like 2.176.3 available at JENKINS_DOWNLOAD_URL
# JENKINS_DOWNLOAD_URL: Specify the endpoint to use for downloading jenkins.war
function downloadJenkinsWar(){
  jv download
}

function getGPGKeyFromAzure(){
  requireAzureKeyvaultCredentials
  azureAccountAuth

  az keyvault secret download \
    --vault-name "$AZURE_VAULT_NAME" \
    --name "$GPG_VAULT_NAME" \
    --file "$GPG_FILE" \
    --encoding base64
}

function generateSettingsXml(){
requireRepositoryPassword
requireKeystorePass
requireGPGPassphrase

cat <<EOT> settings-release.xml
<settings>
  <mirrors>
    <mirror>
      <id>mirror-jenkins-public</id>
      <url>${MAVEN_PUBLIC_JENKINS_REPOSITORY_MIRROR_URL}</url>
      <mirrorOf>repo.jenkins-ci.org</mirrorOf>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>automated-release</id>
      <!-- Following properties can't be defined with -D, as explained here https://issues.apache.org/jira/browse/MNG-4979 -->
      <properties>
        <hudson.sign.keystore>${SIGN_KEYSTORE}</hudson.sign.keystore>
        <hudson.sign.alias>${SIGN_ALIAS}</hudson.sign.alias>
        <hudson.sign.storepass>${SIGN_STOREPASS}</hudson.sign.storepass>
        <jarsigner.certs>true</jarsigner.certs>
        <jarsigner.keypass>${SIGN_STOREPASS}</jarsigner.keypass>
        <jarsigner.errorWhenNotSigned>true</jarsigner.errorWhenNotSigned>
        <gpg.keyname>${GPG_KEYNAME}</gpg.keyname>
        <gpg.passphrase>${GPG_PASSPHRASE}</gpg.passphrase>
      </properties>
      <repositories>
        <repository>
          <id>$MAVEN_REPOSITORY_NAME</id>
          <name>$MAVEN_REPOSITORY_NAME</name>
          <releases>
            <enabled>true</enabled>
            <updatePolicy>always</updatePolicy>
            <checksumPolicy>warn</checksumPolicy>
          </releases>
          <snapshots>
            <enabled>true</enabled>
            <updatePolicy>never</updatePolicy>
            <checksumPolicy>fail</checksumPolicy>
          </snapshots>
          <url>${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}/</url>
          <layout>default</layout>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>$MAVEN_REPOSITORY_NAME</id>
          <name>$MAVEN_REPOSITORY_NAME</name>
          <releases>
            <enabled>true</enabled>
            <updatePolicy>always</updatePolicy>
            <checksumPolicy>warn</checksumPolicy>
          </releases>
          <snapshots>
            <enabled>true</enabled>
            <updatePolicy>never</updatePolicy>
            <checksumPolicy>fail</checksumPolicy>
          </snapshots>
          <url>${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}/</url>
          <layout>default</layout>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <servers>
    <server>
      <id>$MAVEN_REPOSITORY_NAME</id>
      <username>$MAVEN_REPOSITORY_USERNAME</username>
      <password>$MAVEN_REPOSITORY_PASSWORD</password>
    </server>
    <server>
      <id>mirror-jenkins-public</id>
      <username>$MAVEN_REPOSITORY_USERNAME</username>
      <password>$MAVEN_REPOSITORY_PASSWORD</password>
    </server>
    <!--This server id is used by jenkinsci/remoting -->
    <server>
      <id>maven.jenkins-ci.org</id>
      <username>$MAVEN_REPOSITORY_USERNAME</username>
      <password>$MAVEN_REPOSITORY_PASSWORD</password>
    </server>
  </servers>
  <activeProfiles>
    <activeProfile>release</activeProfile>
    <activeProfile>automated-release</activeProfile>
  </activeProfiles>
</settings>
EOT
}

# guessGitBranchInformation tries to guess PROFILE, RELEASELINE, and JENKINS_VERSION based on the git branch
# where security releases match pattern <security>-<RELEASELINE>-<JENKINS_VERSION>
# where stable release match pattern <stable>-<JENKINS_VERSION>
# where weekly release match pattern <master>
# ! It only sets the variables if they are not yet defined
function guessGitBranchInformation(){
  #BRANCH_NAME="security-stable-2.235"
  #BRANCH_NAME="stable-2.235"
  #BRANCH_NAME="master"

  ## If needed, set BRANCH_NAME
  DEFAULT_BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD || echo 'master')"
  : "${BRANCH_NAME:=$DEFAULT_BRANCH_NAME}"

  BRANCH_NAME="${BRANCH_NAME//-/ }"
  IFS=" " read -r -a array <<< "$BRANCH_NAME"

  if [[ "${#array[@]}" == 3 ]] ; then
    echo "Based on branch $BRANCH_NAME, expect a security release"
    if [[ "${array[0]}" != "security" ]]; then
      echo "Wrong branch name '${array[0]}', you probably want 'security-{stable|weekly}-<JENKINS_VERSION>"
      exit 1
    fi
    if [[ "${array[1]}" != "stable" && "${array[1]}" != "weekly" ]]; then
      echo "Wrong release line '${array[0]}', you probably want 'security-{stable|weekly}-<JENKINS_VERSION>"
      exit 1
    fi

    RELEASE_PROFILE="${RELEASE_PROFILE:=${array[0]}}"
    RELEASELINE="${RELEASELINE:=-${array[1]}}"
    JENKINS_VERSION="${JENKINS_VERSION:=${array[2]}}"
  fi

  if [[ "${#array[@]}" == 2 ]] ; then
    echo "Based on branch $BRANCH_NAME, expect a stable release"
    if [[ "${array[0]}" != "stable" ]]; then
      echo "Wrong branch name '${array[0]}', you probably want 'stable-<JENKINS_VERSION>"
      exit 1
    fi
    RELEASE_PROFILE="${RELEASE_PROFILE:=stable}"
    RELEASELINE="${RELEASELINE:=-${array[0]}}"
    JENKINS_VERSION="${JENKINS_VERSION:=${array[1]}}"

  fi


  if [[ "${#array[@]}" == 1 ]] ; then
    echo "Based on branch $BRANCH_NAME, expect a weekly release"
    if [[ "${array[0]}" != "master" ]]; then
      echo "Wrong branch name '${array[0]}', you probably want to use 'master'"
      exit 1
    fi
    RELEASE_PROFILE="${RELEASE_PROFILE:=weekly}"
    RELEASELINE="${RELEASELINE:=}"
    JENKINS_VERSION="${JENKINS_VERSION:=latest}"
  fi
}


function invalidateFastlyCache(){
  : "${FASTLY_API_TOKEN:?Require FASTLY_API_TOKEN env variable}"
  : "${FASTLY_SERVICE_ID:?Require FASTLY_SERVICE_ID env variable}"

  curl \
    -X POST \
    -H "Fastly-Key: $FASTLY_API_TOKEN" \
    -H "Accept: application/json" \
    -H "Fastly-Soft-Purge:1" \
    "https://api.fastly.com/service/$FASTLY_SERVICE_ID/purge_all"

}

function configurePackagingEnv(){

  requireGPGPassphrase

  : "${BRAND:=$WORKSPACE/$WORKING_DIRECTORY/branding/common}"
  : "${RELEASELINE:=}"
  : "${ORGANIZATION:=jenkins.io}"
  : "${BUILDENV:=$WORKSPACE/$WORKING_DIRECTORY/env/release.mk}"
  : "${CREDENTIAL:=$BRAND}" # For now, we just want this variable to be set to not empty
  : "${GPG_PASSPHRASE_FILE:=$WORKSPACE/$WORKING_DIRECTORY/$GPG_KEYNAME.pass}"

cat <<EOT> "$GPG_PASSPHRASE_FILE"
$GPG_PASSPHRASE
EOT

  if [ ! -f "$GPG_PASSPHRASE_FILE" ]; then
    echo "$GPG_PASSPHRASE_FILE wasn't correctly created"
    exit 1
  fi

}

function cleanPackagingEnv(){
  rm "$GPG_PASSPHRASE_FILE"
}

function packaging(){
  # Still function need an access to this Makefile
  # https://github.com/jenkinsci/packaging/blob/master/Makefile
  # if more than parameter is needed then they have to be quoted
  # example: `utils/release.bash --packaging "deb rpm suse"`

  configurePackagingEnv
  make "$@"
}

function prepareRelease(){
  requireGPGPassphrase
  requireKeystorePass
  generateSettingsXml

  printf "\\n Prepare Jenkins Release\\n\\n"

  # Do not display transfer progress when downloading or uploading
  # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
  #mvn -B -s settings-release.xml --no-transfer-progress -Darguments=--no-transfer-progress release:prepare

  # 2020-06-24: --no-transfer-progress doesn't seem to be fully suported in maven release plugin
  # This workaround can be reverted once MRELEASE-1048 is fixed
  # https://issues.apache.org/jira/browse/MRELEASE-1048
  mvn -B -s settings-release.xml --no-transfer-progress -Darguments=-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn release:prepare
}

function promoteStagingMavenArtifacts(){
  printf "\\n Promote Maven Artifacts\\n\\n"

  # Following line will copy every items from source to destination,
  # keeps in mind that it won't delete from source and override on destination if already exist!.
  # It's wise to disable delete permission on destination repository
  # as explained here https://www.jfrog.com/confluence/display/JFROG/Permissions#Permissions-RepositoryPermissions
  DEFAULT_PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS="item --mode copy --source $MAVEN_REPOSITORY_NAME --destination $MAVEN_REPOSITORY_PRODUCTION_NAME --url $MAVEN_REPOSITORY_URL --username $MAVEN_REPOSITORY_USERNAME --password $MAVEN_REPOSITORY_PASSWORD --search '/org/jenkins-ci/main' $(jv get)}"

  : "${PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS:=$DEFAULT_PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS}"

  # Convert to array
  IFS=" " read -r -a PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS <<< "$PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS"

  ../utils/promoteMavenArtifacts.py "${PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS[@]}"


}

function promoteStagingGitRepository(){

  # Ensure we always work from a clean environment
  if [ -d "$RELEASE_GIT_STAGING_REPOSITORY_PATH" ];then
    rm -Rf "$RELEASE_GIT_STAGING_REPOSITORY_PATH"
  fi

  mkdir -p "$RELEASE_GIT_STAGING_REPOSITORY_PATH"
  pushd "$RELEASE_GIT_STAGING_REPOSITORY_PATH"

  # Clone production repository on a specific branch
  git clone --branch "$RELEASE_GIT_PRODUCTION_BRANCH" "$RELEASE_GIT_PRODUCTION_REPOSITORY" .

  # Fetch commits from staging repository
  git fetch "$RELEASE_GIT_STAGING_REPOSITORY" "$RELEASE_GIT_STAGING_BRANCH"

  # Merge commits from staging repository
  git merge --no-edit --log=20 FETCH_HEAD

  git push

  popd

}

function pushCommits(){
  : "${RELEASE_SCM_TAG:?RELEASE_SCM_TAG not definded}"

  # Ensure we use ssh credentials
  git config --get remote.origin.url
  sed -i 's#url = https://github.com/#url = git@github.com:#' .git/config
  git pull
  git push origin "HEAD:$RELEASE_GIT_BRANCH" "$RELEASE_SCM_TAG"
}

function rollback(){
  mvn release:rollback
  git push --delete origin "$RELEASE_SCM_TAG"
}

function stageRelease(){
  requireGPGPassphrase
  requireKeystorePass
  printf "\\n Stage Jenkins Release\\n\\n"
  # Do not display transfer progress when downloading or uploading
  # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
  #mvn -B \
  #  "-DstagingRepository=${MAVEN_REPOSITORY_NAME}::default::${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}" \
  #  -s settings-release.xml \
  #  --no-transfer-progress \
  #  -Darguments=--no-transfer-progress \
  #  release:stage

  # 2020-06-24: --no-transfer-progress doesn't seem to be fully suported in maven release plugin
  # This workaround can be reverted once MRELEASE-1048 is fixed
  # https://issues.apache.org/jira/browse/MRELEASE-1048
  mvn -B \
    "-DstagingRepository=${MAVEN_REPOSITORY_NAME}::default::${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}" \
    -s settings-release.xml \
    --no-transfer-progress \
    -DdeployAtEnd=true \
    -Darguments=-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    release:stage
}

function performRelease(){
  requireGPGPassphrase
  requireKeystorePass
  printf "\\n Perform Jenkins Release\\n\\n"
  # Do not display transfer progress when downloading or uploading
  # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
  # mvn -B \
  #   -s settings-release.xml \
  #   --no-transfer-progress \
  #   -Darguments=--no-transfer-progress \
  #   release:perform


  # 2020-06-24: --no-transfer-progress doesn't seem to be fully suported in maven release plugin
  # This workaround can be reverted once MRELEASE-1048 is fixed
  # https://issues.apache.org/jira/browse/MRELEASE-1048
  mvn -B \
    -s settings-release.xml \
    --no-transfer-progress \
    -DdeployAtEnd=true \
    -Darguments=-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    release:perform
}

function validateKeystore(){
  requireKeystorePass
  keytool -keystore "${SIGN_KEYSTORE}" -storepass "${SIGN_STOREPASS}" -list -alias "${SIGN_ALIAS}"
}

function verifyGPGSignature(){
  gpg --verify "$JENKINS_ASC" "$JENKINS_WAR"
  unzip -qc "$JENKINS_WAR" META-INF/MANIFEST.MF | grep 'Jenkins-Version' | awk '{print $2}'
}

function verifyCertificateSignature(){
  jarsigner -verbose -verify -certs -strict "$JENKINS_WAR"
}

function showReleasePlan(){

cat <<-EOF
    A new $RELEASE_PROFILE release will be generated for the "${RELEASELINE:-weekly}" release).

    This new release will use the git repository: $RELEASE_GIT_REPOSITORY,
    using branch $RELEASE_GIT_BRANCH then push commits to the same location.

    Artifacts will be pushed to the maven repository named "$MAVEN_REPOSITORY_NAME"
    located on "$MAVEN_REPOSITORY_URL" authenticated as "$MAVEN_REPOSITORY_USERNAME"
EOF

}

function showPackagingPlan(){

cat <<-EOF
    New Jenkins core packages will be generated for version $(jv get) for the "${RELEASELINE:-weekly}" release

    Those new packages will be generated based on a war file downloaded
    from $JENKINS_DOWNLOAD_URL

    Once built, packages will be pushed to $PKGSERVER
EOF

  if $GIT_STAGING_REPOSITORY_PROMOTION_ENABLED -eq "true"; then
cat <<-EOF
    Git repository promotion is enabled
    Git commits will be promoted from:
        $RELEASE_GIT_STAGING_REPOSITORY:$RELEASE_GIT_STAGING_BRANCH to
        $RELEASE_GIT_PRODUCTION_REPOSITORY:$RELEASE_GIT_PRODUCTION_BRANCH
EOF
  else
    echo Git Repository promotion is disabled
  fi

  if $MAVEN_STAGING_REPOSITORY_PROMOTION_ENABLED -eq "true"; then

cat <<-EOF
    Maven artifacts promotion is enabled
    Artifacts will be promoted from repository $MAVEN_REPOSITORY_NAME to $MAVEN_REPOSITORY_PRODUCTION_NAME
    located on artifactory at $MAVEN_REPOSITORY_URL
EOF

  else
    echo "Maven repository promotion is disabled"
  fi
}

function syncMirror(){

  # Convert PKGSERVER_SSH_OPTS to an array
  IFS=" " read -r -a PKGSERVER_SSH_OPTS <<< "$PKGSERVER_SSH_OPTS"
  ssh "${PKGSERVER_SSH_OPTS[@]}" "$PKGSERVER" /srv/releases/sync.sh
}

function main(){
  if [ $# -eq 0 ] ;then
    configureGPG
    configureKeystore
    configureGit
    validateKeystore
    verifyGPGSignature
    verifyCertificateSignature
    generateSettingsXml
    prepareRelease
    stageRelease
  else
    while [ $# -gt 0 ];
    do
      case "$1" in
            --cleanRelease) echo "Clean Release" && generateSettingsXml && clean;;
            --cloneReleaseGitRepository) echo "Cloning Jenkins Repository" && cloneReleaseGitRepository ;;
            --configureGPG) echo "ConfigureGPG" && configureGPG ;;
            --configureKeystore) echo "Configure Keystore" && configureKeystore ;;
            --configureGit) echo "Configure Git" && configureGit ;;
            --generateSettingsXml) echo "Generate settings-release.xml" && generateSettingsXml ;;
            --downloadAzureKeyvaultSecret) echo "Download Azure Key Vault Secret" && downloadAzureKeyvaultSecret ;;
            --downloadJenkins) echo "Download Jenkins from maven repository" && downloadJenkinsWar ;;
            --getGPGKeyFromAzure) echo "Download GPG Key from Azure" && getGPGKeyFromAzure ;;
            --invalidateFastlyCache) echo "Invalidating Fastly cache" && invalidateFastlyCache ;;
            --validateKeystore) echo "Validate Keystore"  && validateKeystore ;;
            --verifyGPGSignature) echo "Verify GPG Signature" && verifyGPGSignature ;;
            --verifyCertificateSignature) echo "Verify certificate signature" && verifyCertificateSignature ;;
            --performRelease) echo "Perform Release" && performRelease ;;
            --prepareRelease) echo "Prepare Release" && generateSettingsXml && prepareRelease ;;
            --pushCommits) echo "Push commits on $RELEASE_GIT_BRANCH" && pushCommits ;;
            --showReleasePlan) echo "Show Release Plan" && showReleasePlan ;;
            --showPackagingPlan) echo "Show Packaging Plan" && showPackagingPlan ;;
            --promoteStagingMavenArtifacts) echo "Promote Staging Maven Artifacts" && promoteStagingMavenArtifacts ;;
            --promoteStagingGitRepository) echo "Promote Staging Git Repository" && promoteStagingGitRepository ;;
            --rollback) echo "Rollback release $RELEASE_SCM_TAG" && rollblack ;;
            --stageRelease) echo "Stage Release" && stageRelease ;;
            --packaging) echo 'Execute packaging makefile, quote required around Makefile target' && packaging "$2";;
            --syncMirror) echo 'Trigger mirror synchronization' && syncMirror ;;
            -h) echo "help" ;;
            -*) echo "help" ;;
        esac
        shift
    done
  fi
}

#######################################################################################################################

# guessGitBranchInformation

: "${RELEASE_PROFILE:?Release profile required}"

: "${ROOT_DIR:=$(dirname "$(dirname "$0")")}"

# disable shellcheck warning
# shellcheck source=/dev/null
source "${ROOT_DIR}/profile.d/$RELEASE_PROFILE"

# https://maven.apache.org/maven-release/maven-release-plugin/perform-mojo.html
# mvn -Prelease help:active-profiles

: "${WORKSPACE:=$PWD}" # Normally defined from Jenkins environment

: "${RELEASE_GIT_BRANCH:=experimental}"
: "${WORKING_DIRECTORY:=release}"
: "${GIT_EMAIL:=jenkins-bot@example.com}"
: "${GIT_NAME:=jenkins-bot}"
: "${GIT_SSH_COMMAND:=/usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
: "${GPG_KEYNAME:=test-jenkins-release}"
: "${GPG_FILE:=gpg-test-jenkins-release.gpg}"
: "${GPG_VAULT_NAME:=gpg-test-jenkins-release-gpg}"
: "${JENKINS_VERSION:=latest}"
: "${JENKINS_WAR:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war}"
: "${JENKINS_ASC:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war.asc}"
: "${PKGSERVER:=mirrorbrain@pkg.origin.jenkins.io}"
: "${SIGN_ALIAS:=jenkins}"
: "${SIGN_KEYSTORE_FILENAME:=jenkins.pfx}"
: "${SIGN_KEYSTORE:=${WORKSPACE}/${SIGN_KEYSTORE_FILENAME}}"
: "${SIGN_CERTIFICATE:=$SIGN_KEYSTORE_FILENAME}"
: "${MAVEN_REPOSITORY_USERNAME:=jenkins-bot}"
: "${MAVEN_REPOSITORY_URL:=https://repo.jenkins-ci.org}"
: "${MAVEN_REPOSITORY_NAME:=releases}"
: "${MAVEN_REPOSITORY_PRODUCTION_NAME:=releases}"
: "${MAVEN_REPOSITORY_SNAPSHOT_NAME:=releases}"
: "${MAVEN_PUBLIC_JENKINS_REPOSITORY_MIRROR_URL:=https://repo.jenkins-ci.org/public/}"
: "${PKGSERVER_SSH_OPTS:=-p 22}"

: "${JENKINS_DOWNLOAD_URL:=$MAVEN_REPOSITORY_URL/$MAVEN_REPOSITORY_NAME/org/jenkins-ci/main/jenkins-war/}"

# Promotion Settings
: "${RELEASE_GIT_STAGING_REPOSITORY_PATH:=$WORKSPACE/stagingGitRepository}"
: "${RELEASE_GIT_STAGING_REPOSITORY:=$RELEASE_GIT_REPOSITORY}"
: "${RELEASE_GIT_STAGING_BRANCH:=$RELEASE_GIT_BRANCH}"
: "${RELEASE_GIT_PRODUCTION_REPOSITORY:=$RELEASE_GIT_REPOSITORY }"
: "${RELEASE_GIT_PRODUCTION_BRANCH:=$RELEASE_GIT_BRANCH}"

export JENKINS_VERSION
export JENKINS_DOWNLOAD_URL
export MAVEN_REPOSITORY_USERNAME
export MAVEN_REPOSITORY_PASSWORD
export WAR
export BRAND
export RELEASELINE
export ORGANIZATION
export BUILDENV
export CREDENTIAL
export GPG_PASSPHRASE_FILE
export GPG_KEYNAME

export RELEASE_PROFILE
export RELEASELINE
export JENKINS_VERSION


if [ ! -d "$WORKING_DIRECTORY" ]; then
  mkdir -p "$WORKING_DIRECTORY"
fi

pushd $WORKING_DIRECTORY


main "$@"
