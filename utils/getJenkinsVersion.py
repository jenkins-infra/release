#!/usr/bin/env python3

from urllib.request import URLError
import urllib.request
import base64
import xml.etree.ElementTree as ET
import os
import argparse
import sys


def get_latest_version(versions):

    results = []
    for i in range(10):
        solutions = []
        for version in versions:
            values = version.split('.')

            str_results = [str(x) for x in results]

            if len(results) < len(values) and str_results[0:len(results)] == values[0:len(results)]:
                try:
                    if int(values[i]) not in solutions:
                        solutions.append(int(values[i]))
                except Exception as e:
                    print("Ignoring version {}".format(values[i]))

        if not solutions:
            break

        results.append(int(sorted(solutions)[-1]))

    str_results = [str(x) for x in results]
    return '.'.join(str_results)


def get_jenkins_version(metadata_url, version_identifier, username, password):
    '''
        getJenkinsVersion retrieves a Jenkins version number
        from a maven repository
    '''

    try:
        request = urllib.request.Request(metadata_url)

        if username != "":
            base64string = base64.b64encode(
                bytes('%s:%s' % (username, password), 'ascii'))

            request.add_header(
                "Authorization", "Basic %s" % base64string.decode('utf-8'))

        response = urllib.request.urlopen(request)

        tree = ET.parse(response)

        root = tree.getroot()

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y.Z which represents stable version

        if version_identifier == 'latest':
            result = root.find('versioning/latest').text

        # In this case we assume that we provided a valid version
        elif len(version_identifier.split('.')) > 0:
            result = version_identifier
            versions = root.findall('versioning/versions/version')

            found = []

            for version in versions:
                result_array = result.split('.')
                version_array = version.text.split('.')
                if len(version_array) >= len(result_array):
                    if result_array[:] == version_array[0:len(result_array)] and len(result_array) > 0:
                        found.append(version.text)

            result = get_latest_version(found)

        else:
            print("Something went wrong with version: {}".format(version))
            sys.exit(1)

        return result

    except URLError as error:
        msg = 'Something went wrong while retrieving Jenkins version: {}'
        print(msg.format(error))
        sys.exit(1)


def download_jenkins(url, username, password, version, path):
    ''' download_jenkins download locally a jenkins.war'''

    download_url = url + f'{version}/jenkins-war-{version}.war'

    print("Downloading version {} from {} ".format(version, download_url))

    try:
        request = urllib.request.Request(download_url)

        if username != "":
            base64string = base64.b64encode(
                bytes('%s:%s' % (username, password), 'ascii'))

            request.add_header(
                "Authorization", "Basic %s" % base64string.decode('utf-8'))

        response = urllib.request.urlopen(request)
        content = response.read()

        open(path, 'wb').write(content)

        print("War downloaded to {}".format(path))

    except URLError as err:
        print(type(err))
        sys.exit(1)




def main():

    username = os.environ.get('MAVEN_REPOSITORY_USERNAME', '')
    password = os.environ.get('MAVEN_REPOSITORY_PASSWORD', '')

    path = os.environ.get('WAR', '/tmp/jenkins.war')

    url = os.environ.get(
        'JENKINS_DOWNLOAD_URL',
        'https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/')

    version = get_jenkins_version(
        url + 'maven-metadata.xml',
        os.environ.get('JENKINS_VERSION', 'latest'),
        username,
        password
        )

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-v",
        "--version",
        help="Only Show Jenkins version",
        action="store_true")

    args = parser.parse_args()

    if args.version:
        print(f"{version}")
        sys.exit(0)

    download_jenkins(url, username, password, version, path)


if __name__ == "__main__":
    main()
