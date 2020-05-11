#!/usr/bin/env python3

import os
import re
import sys
import argparse
import requests

URL = os.environ.get("MAVEN_REPOSITORY_URL", "https://repo.jenkins-ci.org")
USERNAME = os.environ.get("MAVEN_REPOSITORY_USERNAME")
PASSWORD = os.environ.get("MAVEN_REPOSITORY_PASSWORD")

srcRepoKey = os.environ.get("MAVEN_REPOSITORY_SOURCE_NAME")
targetRepoKey = os.environ.get("MAVEN_REPOSITORY_TARGET_NAME")


# directories = [
#     "/org/jenkins-ci/main/cli",
#     "/org/jenkins-ci/main/jenkins-bom",
#     "/org/jenkins-ci/main/jenkins-core",
#     "/org/jenkins-ci/main/jenkins-parent",
#     "/org/jenkins-ci/main/jenkins-war",
# ]


def get_api_version():

    """
        getApiVersion() return the api version
    """

    url = URL + '/api/system/version'

    response = requests.get(url,
                            auth=requests.auth.HTTPBasicAuth(
                                USERNAME,
                                PASSWORD))

    return response.json()['version']


def copy_item(srcRepoKey, srcFilePath,
              targetRepoKey, targetFilePath,
              dryRun, suppressLayout, failFast):
    """
        Copy will update items between two repositories
        then update the metadata.xml
    """

    url = f"{ URL }/api/copy/{ srcRepoKey }{ srcFilePath }?to=/{ targetRepoKey}/{ targetFilePath }&dry={ dryRun }&suppressLayout={ suppressLayout} 0&failFAst={ failFast }"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 USERNAME,
                                 PASSWORD))
    j = response.json()

    print(url)
    print(j)

    for result in j['messages']:
        print(f"{result['message']}")

    print("\n")


def get_directories(repository, path, version):
    """
        get_directories tries to guess,
        based on a path and a version,
        which items will need to be copied
    """

    directories = []

    payload = f'''items.find({{"$and":[{{"repo":{{"$eq": "{ repository }"}}}},{{"path":{{"$match": "{ path[1:] }/*/{version}"}}}}]}}).include("repo","name","path")'''

    url = f"{ URL }/api/search/aql"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 USERNAME,
                                 PASSWORD),
                             data=payload)

    j = response.json()

    for result in j["results"]:
        path = "/" + result["path"]
        if path not in directories:
            directories.append(path)

    return directories


def is_directory_exist(repository, directory):
    """
        is_directory_exist query a maven repository
        to see if a directory already exist
    """
    url = URL + '/api/storage/' + repository + directory

    response = requests.get(url,
                            auth=requests.auth.HTTPBasicAuth(
                                USERNAME,
                                PASSWORD))

    if response.status_code != 200:
        return False

    return response.status_code == 200


def is_alive():
    """
        is_alive test if a maven repository is reachable based on a ping test
    """
    url = URL + '/api/system/ping'

    response = requests.get(url,
                            auth=requests.auth.HTTPBasicAuth(
                                USERNAME,
                                PASSWORD))

    return response.status_code == 200


def is_required_parameters():
    """
        is_required_parameters check if all settings are provided
    """
    result = True

    if not URL:
        print("Missing environment variable MAVEN_REPOSITORY_URL")
        result = False
    if not USERNAME:
        print("Missing environment variable MAVEN_REPOSITORY_USERNAME")
        result = False
    if not PASSWORD:
        print("Missing environment variable MAVEN_REPOSITORY_USERNAME")
        result = False
    if not srcRepoKey:
        print("Missing environment variable MAVEN_REPOSITORY_SOURCE_NAME")
        result = False
    if not targetRepoKey:
        print("Missing environment variable MAVEN_REPOSITORY_TARGET_NAME")
        result = False
    if not VERSION:
        print("Missing environment variable JENKINS_VERSION")
        result = False

    return result


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("version",
                        help="specify version that need to be promoted")
    parser.add_argument("--dry_run",
                        help="Don't copy items",
                        action="store_true")

    args = parser.parse_args()

    VERSION = args.version
    dryrun = int(args.dry_run)

    if not is_required_parameters():
        sys.exit(1)

    if not is_alive():
        print(f"{ URL } not reachable")
        sys.exit(2)

    print(f"Artifactory version: {get_api_version()}\n")

    directories = get_directories(srcRepoKey, "/org/jenkins-ci/main", VERSION)

    for index, directory in enumerate(directories, start=1):
        srcFilePath = directory
        targetFilePath = re.sub("/" + VERSION + "$", '', directory)

        print(f"[{index}/{len(directories)}] - {srcFilePath}")

        if not is_directory_exist(targetRepoKey, directory):
            print(f"\nCopying '{directory}' from { srcRepoKey } to { targetRepoKey }\n")
            copy_item(srcRepoKey,
                      srcFilePath,
                      targetRepoKey,
                      targetFilePath,
                      dryrun,
                      0,
                      1)
        else:
            print(f"\nAlready exist on { targetRepoKey }\n")
