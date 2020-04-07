#!/bin/bash

set -euxo pipefail

: "${RELEASE_PROFILE:?Release profile required}"

source ""$(dirname "$(dirname "$0")")"/profile.d/$RELEASE_PROFILE"

# https://maven.apache.org/maven-release/maven-release-plugin/perform-mojo.html
# mvn -Prelease help:active-profiles

: "${WORKSPACE:=$PWD}" # Normally defined from Jenkins environment

: "${JENKINS_GIT_BRANCH:=experimental}"
: "${WORKING_DIRECTORY:=release}"
: "${GIT_EMAIL:=jenkins-bot@example.com}"
: "${GIT_NAME:=jenkins-bot}"
: "${GIT_SSH_COMMAND:=/usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
: "${GPG_KEYNAME:=test-jenkins-release}"
: "${GPG_FILE:=gpg-test-jenkins-release.gpg}"
: "${GPG_VAULT_NAME:=gpg-test-jenkins-release-gpg}"
: "${JENKINS_VERSION:=weekly}"
: "${JENKINS_WAR:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war}"
: "${JENKINS_ASC:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war.asc}"
: "${PKGSERVER:=mirrorbrain@pkg.jenkins.io}"
: "${SIGN_ALIAS:=jenkins}"
: "${SIGN_KEYSTORE_FILENAME:=jenkins.pfx}"
: "${SIGN_KEYSTORE:=${WORKSPACE}/${SIGN_KEYSTORE_FILENAME}}"
: "${SIGN_CERTIFICATE:=$SIGN_KEYSTORE_FILENAME}"
: "${MAVEN_REPOSITORY_USERNAME:=jenkins-bot}"
: "${MAVEN_REPOSITORY_URL:=http://nexus/repository}"
: "${MAVEN_REPOSITORY_NAME:=maven-releases}"
: "${MAVEN_REPOSITORY_SNAPSHOT_NAME:=maven-snapshots}"
: "${MAVEN_PUBLIC_JENKINS_REPOSITORY_MIRROR_URL:=http://nexus/repository/jenkins-public/}"
: "${PKGSERVER_SSH_OPTS:=-p 22}"

: "${JENKINS_DOWNLOAD_URL:=$MAVEN_REPOSITORY_URL/$MAVEN_REPOSITORY_NAME/org/jenkins-ci/main/jenkins-war/}"

if [ ! -d "$WORKING_DIRECTORY" ]; then
  mkdir -p "$WORKING_DIRECTORY"
fi

pushd $WORKING_DIRECTORY

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
    mvn -s settings-release.xml -B --no-transfer-progress -Darguments=--no-transfer-progress release:clean
}

function cloneJenkinsGitRepository(){
  # `ssh` is needed as git clone doesn't use GIT_SSH_COMMAND
  # https://git-scm.com/docs/git#Documentation/git.txt-codeGITSSHCOMMANDcode
  ssh -o StrictHostKeyChecking=no -T git@github.com || true
  git clone --branch "${JENKINS_GIT_BRANCH}" "${JENKINS_GIT_REPOSITORY}" .
}

function configureGit(){
  git checkout "${JENKINS_GIT_BRANCH}"
  git config --local user.email "${GIT_EMAIL}"
  git config --local user.name "${GIT_NAME}"
}

function configureGPG(){
  requireGPGPassphrase
  if ! gpg --fingerprint "${GPG_KEYNAME}"; then
    if [ ! -f "${GPG_FILE}" ]; then
      exit "${GPG_KEYNAME} or ${GPG_FILE} cannot be found"
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
      exit "${SIGN_CERTIFICATE} not found"
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
      openssl pkcs12 -in ${SIGN_CERTIFICATE} -out tmpjenkins.pem -nodes -passin pass:""
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
# * \'stable\' means the latest stable version that satifies version pattern X.Y.Z
# * \'weekly\' means the latest weekly version that satisfies version pattern X.Y 
# * <version> represents any valid existing version like 2.176.3 available at JENKINS_DOWNLOAD_URL
# JENKINS_DOWNLOAD_URL: Specify the endpoint to use for downloading jenkins.war 
function downloadJenkinsWar(){
  pwd
  "$WORKSPACE"/utils/getJenkinsVersion.py
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
  </servers>
  <activeProfiles>
    <activeProfile>release</activeProfile>
    <activeProfile>automated-release</activeProfile>
  </activeProfiles>
</settings>
EOT
}

function configurePackagingEnv(){

  requireGPGPassphrase

  : "${BRAND:=$WORKSPACE/$WORKING_DIRECTORY/branding/common}"
  : "${RELEASELINE:=}"
  : "${ORGANIZATION:=jenkins.io}"
  : "${BUILDENV:=$WORKSPACE/$WORKING_DIRECTORY/env/release.mk}"
  : "${CREDENTIAL:=$BRAND}" # For now, we just want this variable to be set to not empty
  : "${GPG_PASSPHRASE_FILE:=$WORKSPACE/$WORKING_DIRECTORY/$GPG_KEYNAME.pass}"

  export BRAND
  export RELEASELINE
  export ORGANIZATION
  export BUILDENV
  export CREDENTIAL
  export GPG_PASSPHRASE_FILE
  export GPG_KEYNAME

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
  # example: `utils/release.sh --packaging "deb rpm suse"`

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
  mvn -B -s settings-release.xml --no-transfer-progress -Darguments=--no-transfer-progress release:prepare
}

function pushCommits(){
  : "${RELEASE_SCM_TAG:?RELEASE_SCM_TAG not definded}"

  # Ensure we use ssh credentials
  git config --get remote.origin.url
  sed -i 's#url = https://github.com/#url = git@github.com:#' .git/config
  git pull 
  git push origin "HEAD:$JENKINS_GIT_BRANCH" "$RELEASE_SCM_TAG"
}

function rollback(){
  mvn release:rollback
  git push --delete origin "$RELEASE_SCM_TAG"
}

function stageRelease(){
  requireGPGPassphrase
  requireKeystorePass
  printf "\\n Perform Jenkins Release\\n\\n"
  # Do not display transfer progress when downloading or uploading
  # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
  mvn -B \
    "-DstagingRepository=${MAVEN_REPOSITORY_NAME}::default::${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}" \
    -s settings-release.xml \
    --no-transfer-progress \
    -Darguments=--no-transfer-progress \
    release:stage
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

function syncMirror(){

  PKGSERVER_SSH_OPTS=($PKGSERVER_SSH_OPTS)
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
            --cloneJenkinsGitRepository) echo "Cloning Jenkins Repository" && cloneJenkinsGitRepository ;;
            --configureGPG) echo "ConfigureGPG" && configureGPG ;;
            --configureKeystore) echo "Configure Keystore" && configureKeystore ;;
            --configureGit) echo "Configure Git" && configureGit ;;
            --generateSettingsXml) echo "Generate settings-release.xml" && generateSettingsXml ;;
            --downloadAzureKeyvaultSecret) echo "Download Azure Key Vault Secret" && downloadAzureKeyvaultSecret ;;
            --downloadJenkins) echo "Download Jenkins from maven repository" && downloadJenkinsWar ;;
            --getGPGKeyFromAzure) echo "Download GPG Key from Azure" && getGPGKeyFromAzure ;;
            --validateKeystore) echo "Validate Keystore"  && validateKeystore ;;
            --verifyGPGSignature) echo "Verify GPG Signature" && verifyGPGSignature ;;
            --verifyCertificateSignature) echo "Verify certificate signature" && verifyCertificateSignature ;;
            --prepareRelease) echo "Prepare Release" && generateSettingsXml && prepareRelease ;;
            --pushCommits) echo "Push commits on $JENKINS_GIT_BRANCH" && pushCommits ;;
            --rollback) echo "Rollback release $RELEASE_SCM_TAG" && rollblack ;;
            --stageRelease) echo "Perform Release" && stageRelease ;;
            --packaging) echo 'Execute packaging makefile, quote required around Makefile target' && packaging "$2";;
            --syncMirror) echo 'Trigger mirror synchronization' && syncMirror ;;
            -h) echo "help" ;;
            -*) echo "help" ;;
        esac
        shift
    done
  fi
}

main "$@"
