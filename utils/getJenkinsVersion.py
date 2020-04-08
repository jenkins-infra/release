#!/usr/bin/env python3

from urllib.request import URLError
import urllib.request
import base64
import xml.etree.ElementTree as ET
import os


USERNAME = os.environ.get('MAVEN_REPOSITORY_USERNAME', '')
PASSWORD = os.environ.get('MAVEN_REPOSITORY_PASSWORD', '')


PATH = os.environ.get('WAR', '/tmp/jenkins.war')

# URL = 'https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/'
URL = os.environ.get(
    'JENKINS_DOWNLOAD_URL',
    'https://release.repo.jenkins.io/repository/maven-releases/org/jenkins-ci/main/jenkins-war/')


def getJenkinsVersion(metadataUrl, version):

    try:
        request = urllib.request.Request(metadataUrl)

        if USERNAME != "":
            base64string = base64.b64encode(
                bytes('%s:%s' % (USERNAME, PASSWORD), 'ascii'))

            request.add_header(
                "Authorization", "Basic %s" % base64string.decode('utf-8'))

        response = urllib.request.urlopen(request)

        tree = ET.parse(response)

        root = tree.getroot()

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y.Z which represents stable version

        if version == 'stable':
            versions = root.findall('versioning/versions/version')

            for version in versions:
                if len(version.text.split('.')) == 3:
                    result = version.text

            print("Latest Stable Jenkins version detected: {}".format(result))

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y which represents weekly version
        elif version == 'weekly':
            result = root.find('versioning/release').text
            print("Latest Jenkins version detected: {}".format(result))

        # In this case we assume that we provided a valid version
        elif len(version.split('.')) > 0:
            result = version
            print("Jenkins version specified: {}".format(result))

        else:
            print("Something went wrong with version: {}".format(version))
            exit(1)

        return result

    except URLError as e:
        msg = 'Something went wrong while retrieving stable version: {}'
        print(msg.format(e))
        exit(1)


def downloadJenkins(version):
    downloadUrl = URL + '{}/jenkins-war-{}.war'.format(version, version)

    print("Downloading version {} from {} ".format(version, downloadUrl))

    try:
        request = urllib.request.Request(downloadUrl)

        if USERNAME != "":
            base64string = base64.b64encode(
                bytes('%s:%s' % (USERNAME, PASSWORD), 'ascii'))

            request.add_header(
                "Authorization", "Basic %s" % base64string.decode('utf-8'))

        response = urllib.request.urlopen(request)
        content = response.read().decode(encoding='utf-8', errors='ignore')

        f = open(PATH, 'w')
        f.write(content)
        f.close()
        print("War downloaded to {}".format(PATH))

    except URLError as e:
        print(type(e))
        exit(1)


VERSION = getJenkinsVersion(
    URL + 'maven-metadata.xml',
    os.environ.get('JENKINS_VERSION', 'weekly')
    )


def main():
    print("VERSION: " + VERSION)
    print("Downloaded from: " + URL)
    downloadJenkins(VERSION)


if __name__ == "__main__":
    main()
