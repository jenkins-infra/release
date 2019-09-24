#!/usr/bin/env python2

import urllib2
import xml.etree.ElementTree as ET
import os


def getJenkinsVersion(metadataUrl, version):
    try:
        url = metadataUrl
        tree = ET.parse(urllib2.urlopen(url))
        root = tree.getroot()

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y.Z which represents stable version

        if version == 'stable':
            versions = root.findall('versioning/versions/version')

            for version in versions:
                if len(version.text.split('.')) == 3:
                    result = version.text

            print "Latest Stable Jenkins version detected: {}".format(result)

        # Search in Maven repository for latest version of Jenkins
        # that satisfies X.Y which represents weekly version
        elif version == 'weekly':
            result = root.find('versioning/release').text
            print "Latest Jenkins version detected: {}".format(result)

        # In this case we assume that we provided a valid version
        elif len(version.split('.')) > 0:
            result = version
            print "Jenkins version specified: {}".format(result)

        else:
            print "Something went wrong with version: {}".format(version)
            exit(1)

        return result

    except urllib2.URLError as e:
        msg = 'Something went wrong while retrieving stable version: {}'
        print msg.format(e)
        exit(1)


def downloadJenkins(version):
    downloadUrl = URL + '{}/jenkins-war-{}.war'.format(version, version)

    print "Downloading version {} from {} ".format(version, downloadUrl)

    try:
        response = urllib2.urlopen(downloadUrl)
        content = response.read()

        f = open(PATH, 'w')
        f.write(content)
        f.close()
        print "War downloaded to {}".format(PATH)

    except urllib2.URLError as e:
        print type(e)
        exit(1)


# URL = 'https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/'
URL = os.environ.get('JENKINS_DOWNLOAD_URL', 'https://release.repo.jenkins.io/repository/maven-releases/org/jenkins-ci/main/jenkins-war/')

PATH = os.environ.get('WAR', '/tmp/jenkins.war')
VERSION = getJenkinsVersion(
    URL + 'maven-metadata.xml',
    os.environ.get('JENKINS_VERSION', 'weekly')
    )

def main():
    print "VERSION: " + VERSION
    print "Downloaded from: " + URL
    downloadJenkins(VERSION)


if __name__ == "__main__":
    main()
