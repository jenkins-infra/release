#!/usr/bin/env python3

from urllib.request import URLError
import urllib.request
import base64
import xml.etree.ElementTree as ET
import os
import argparse
import sys


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

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y which represents weekly version
        elif version == 'weekly':
            result = root.find('versioning/latest').text

        # In this case we assume that we provided a valid version
        elif len(version.split('.')) > 0:
            result = version

        else:
            print("Something went wrong with version: {}".format(version))
            sys.exit(1)

        return result

    except URLError as error:
        msg = 'Something went wrong while retrieving stable version: {}'
        print(msg.format(error))
        sys.exit(1)


def downloadJenkins(version):
    download_url = URL + f'{version}/jenkins-war-{version}.war'

    print("Downloading version {} from {} ".format(version, download_url))

    try:
        request = urllib.request.Request(download_url)

        if USERNAME != "":
            base64string = base64.b64encode(
                bytes('%s:%s' % (USERNAME, PASSWORD), 'ascii'))

            request.add_header(
                "Authorization", "Basic %s" % base64string.decode('utf-8'))

        response = urllib.request.urlopen(request)
        content = response.read()

        open(PATH, 'wb').write(content)

        print("War downloaded to {}".format(PATH))

    except URLError as err:
        print(type(err))
        sys.exit(1)


VERSION = getJenkinsVersion(
    URL + 'maven-metadata.xml',
    os.environ.get('JENKINS_VERSION', 'weekly')
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-v",
        "--version",
        help="Only Show Jenkins version",
        action="store_true")

    args = parser.parse_args()

    if args.version:
        print(f"{VERSION}")
        sys.exit(0)

    print("VERSION: " + VERSION)
    print("Downloaded from: " + URL)
    downloadJenkins(VERSION)


if __name__ == "__main__":
    main()
