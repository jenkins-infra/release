#!/usr/bin/env python3

# Test getJenkinsVersion.py

import unittest
import os

# import getJenkinsVersion
from getJenkinsVersion import get_latest_version, get_jenkins_version

USERNAME = os.environ.get('MAVEN_REPOSITORY_USERNAME', '')
PASSWORD = os.environ.get('MAVEN_REPOSITORY_PASSWORD', '')


# Test that GetJenkinsVersion returns the correct value
class TestGetJenkinsVersion(unittest.TestCase):
    '''Unit Test getJenkinversion.py scripts'''

    data_set = {
        'all_versions': [
            "1", "1.10", "1.11", "1.10.1", "1.10.2", "1.11.0", "1.11.2",
            "2", "2.10", "2.11", "2.10.1", "2.10.2", "2.11.0", "2.11.2",
            "2.99", "2.249", "2.265", "2.279"
        ],
        'url': "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml",
        'versions': [
            {
                'name': 'latest',
                'expected': '2.265'
            },
            {
                'name': '2',
                'expected': '2.265'
            },
            {
                'name': '2.249',
                'expected': '2.249.3'
            },
            {
                'name': '2.249.3',
                'expected': '2.249.3'
            }],
    }

    def test_latest_version(self):
        '''Test that we correclty get Jenkins version value'''

        result = get_latest_version(self.data_set["all_versions"])
        self.assertEqual("2.279", result)

    def test_result(self):
        '''Test that we correclty get Jenkins version value'''

        for version in self.data_set["versions"]:
            result = get_jenkins_version(self.data_set["url"],
                                         version["name"],
                                         USERNAME,
                                         PASSWORD)
            self.assertEqual(version["expected"], result)


if __name__ == '__main__':
    unittest.main()
