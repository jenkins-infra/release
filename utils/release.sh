#!/bin/bash

set -euxo pipefail

# https://maven.apache.org/maven-release/maven-release-plugin/perform-mojo.html
# mvn -Prelease help:active-profiles

#: "${WORKSPACE:=$PWD}" # Normally defined from Jenkins environment

: "${BRANCH_NAME:=experimental}"
: "${GIT_REPOSITORY:=scm:git:git://github.com/jenkinsci/jenkins.git}"
: "${GIT_EMAIL:=jenkins-bot@example.com}"
: "${GIT_NAME:=jenkins-bot}"
: "${GIT_SSH:=ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
: "${GPG_KEYNAME:=test-jenkins-release}"
: "${GPG_FILE:=gpg-test-jenkins-release.gpg}"
: "${JENKINS_WAR:=$WORKSPACE/war/target/jenkins.war}"
: "${JENKINS_ASC:=$WORKSPACE/war/target/jenkins.war.asc}"
: "${SIGN_ALIAS:=jenkins}"
: "${SIGN_KEYSTORE:=${WORKSPACE}/jenkins.pfx}"
: "${SIGN_CERTIFICATE:=jenkins.pem}"
: "${MAVEN_REPOSITORY_USERNAME:=jenkins-bot}"
: "${MAVEN_REPOSITORY_URL:=http://nexus/repository}"
: "${MAVEN_REPOSITORY_NAME:=maven-releases}"
: "${MAVEN_REPOSITORY_SNAPSHOT_NAME:=maven-snapshots}"
: "${MAVEN_PUBLIC_JENKINS_REPOSITORY_MIRROR_URL:=http://nexus/repository/jenkins-public/}"

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
    mvn -s settings-release.xml -B  release:clean
}

function configureGit(){
  git checkout "${BRANCH_NAME}"
  git config --local user.email "${GIT_EMAIL}"
  git config --local user.name "${GIT_NAME}"
}

function configureGPG(){
  requireGPGPassphrase
  if ! gpg --fingerprint "${GPG_KEYNAME}"; then
    if [ ! -f "${GPG_FILE}" ]; then
      exit "${GPG_KEYNAME} or ${GPG_FILE} cannot be found"
    else
      ## --pinenty-mode is needed to avoid gpg prompt during maven release
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
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
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
  </activeProfiles>
</settings>
EOT
}

function prepareRelease(){
  requireGPGPassphrase
  requireKeystorePass
  printf "\\n Prepare Jenkins Release\\n\\n"
  mvn -B \
    "-Darguments='-DskipTests'" \
    "-DtagNameFormat='release-@{project.version}'" \
    "-DpushChanges=false" \
    "-DlocalCheckout=true" \
    "-Djarsigner.keystore=${SIGN_KEYSTORE}" \
    "-Djarsigner.alias=${SIGN_ALIAS}" \
    "-Djarsigner.storepass=${SIGN_STOREPASS}" \
    "-Djarsigner.certs=true" \
    "-Djarsigner.keypass=${SIGN_STOREPASS}" \
    "-Djarsigner.errorWhenNotSigned=true" \
    "-Dgpg.keyname=${GPG_KEYNAME}" \
    "-Dgpg.passphrase=${GPG_PASSPHRASE}" \
    -s settings-release.xml \
    release:prepare
}

function pushCommits(){
  : "${RELEASE_SCM_TAG:?RELEASE_SCM_TAG not definded}"

  # Ensure we use ssh credentials
  sed -i 's#url = https://github.com/#url = git@github.com:#' .git/config
  git push origin "HEAD:$BRANCH_NAME" "$RELEASE_SCM_TAG"
}

function rollback(){
  mvn release:rollback
  git push --delete origin "$RELEASE_SCM_TAG"
}

function stageRelease(){
  requireGPGPassphrase
  requireKeystorePass
  printf "\\n Perform Jenkins Release\\n\\n"
  mvn -B \
    "-Darguments='-DskipTests'" \
    "-DstagingRepository=${MAVEN_REPOSITORY_NAME}::default::${MAVEN_REPOSITORY_URL}/${MAVEN_REPOSITORY_NAME}" \
    -s settings-release.xml \
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
            --configureGPG) echo "ConfigureGPG" && configureGPG ;;
            --configureKeystore) echo "Configure Keystore" && configureKeystore ;;
            --configureGit) echo "Configure Git" && configureGit ;;
            --generateSettingsXml) echo "Generate settings-release.xml" && generateSettingsXml ;;
            --downloadAzureKeyvaultSecret) echo "Download Azure Key Vault Secret" && downloadAzureKeyvaultSecret ;;
            --getGPGKeyFromAzure) echo "Download GPG Key from Azure" && getGPGKeyFromAzure ;;
            --validateKeystore) echo "Validate Keystore"  && validateKeystore ;;
            --verifyGPGSignature) echo "Verify GPG Signature" && verifyGPGSignature ;;
            --prepareRelease) echo "Prepare Release" && generateSettingsXml && prepareRelease ;;
            --pushCommits) echo "Push commits on $BRANCH_NAME" && pushCommits ;;
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
