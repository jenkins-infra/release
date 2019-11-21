#!/bin/bash

set -euxo pipefail

: "${RELEASE_PROFILE:=weekly}"

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
: "${JENKINS_WAR:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war}"
: "${JENKINS_ASC:=$WORKSPACE/$WORKING_DIRECTORY/war/target/jenkins.war.asc}"
: "${SIGN_ALIAS:=jenkins}"
: "${SIGN_KEYSTORE:=${WORKSPACE}/jenkins.pfx}"
: "${SIGN_CERTIFICATE:=jenkins.pem}"
: "${MAVEN_REPOSITORY_USERNAME:=jenkins-bot}"
: "${MAVEN_REPOSITORY_URL:=http://nexus/repository}"
: "${MAVEN_REPOSITORY_NAME:=maven-releases}"
: "${MAVEN_REPOSITORY_SNAPSHOT_NAME:=maven-snapshots}"
: "${MAVEN_PUBLIC_JENKINS_REPOSITORY_MIRROR_URL:=http://nexus/repository/jenkins-public/}"

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
    mvn -s settings-release.xml -B --no-transfer-progress release:clean
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
  else
    openssl pkcs12 -export \
      -out "$SIGN_KEYSTORE" \
      -in "${SIGN_CERTIFICATE}" \
      -password "pass:$SIGN_STOREPASS" \
      -name "$SIGN_ALIAS"
  fi
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
    --file "$AZURE_VAULT_FILE"
}

function getGPGKeyFromAzure(){
  az storage blob download \
    --account-name "$AZURE_STORAGE_ACCOUNT" \
    --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
    --name "$GPG_FILE" \
    --file "$GPG_FILE"
}

function getGPGKeyFromAzure(){
  az storage blob download \
    --account-name "$AZURE_STORAGE_ACCOUNT" \
    --container-name "$AZURE_STORAGE_CONTAINER_NAME" \
    --name "$GPG_FILE" \
    --file "$GPG_FILE"
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

function prepareRelease(){
  requireGPGPassphrase
  requireKeystorePass
  generateSettingsXml

  printf "\\n Prepare Jenkins Release\\n\\n"

  # Do not display transfer progress when downloading or uploading
  # https://maven.apache.org/ref/3.6.1/maven-embedder/cli.html
  mvn -B -s settings-release.xml --no-transfer-progress release:prepare
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

function main(){
  if [ $# -eq 0 ] ;then
    configureGPG
    configureKeystore
    configureGit
    validateKeystore
    verifyGPGSignature
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
            --getGPGKeyFromAzure) echo "Download GPG Key from Azure" && getGPGKeyFromAzure ;;
            --validateKeystore) echo "Validate Keystore"  && validateKeystore ;;
            --verifyGPGSignature) echo "Verify GPG Signature" && verifyGPGSignature ;;
            --prepareRelease) echo "Prepare Release" && generateSettingsXml && prepareRelease ;;
            --pushCommits) echo "Push commits on $JENKINS_GIT_BRANCH" && pushCommits ;;
            --rollback) echo "Rollback release $RELEASE_SCM_TAG" && rollblack ;;
            --stageRelease) echo "Perform Release" && stageRelease ;;
            -h) echo "help" ;;
            -*) echo "help" ;;
        esac
        shift
    done
  fi
}

main "$@"
