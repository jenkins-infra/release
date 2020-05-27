#!/usr/bin/env python3

import re
import sys
import argparse
import requests



def get_api_version(url,username,password):
    """
        getApiVersion() return the api version
    """

    url = url + '/api/system/version'

    response = requests.get(url,
                            auth=requests.auth.HTTPBasicAuth(
                                username,
                                password))

    return response.json()['version']


def calculate_metadata(url, username, password, destination, path):
    """
        Calculate metadata will recursively update metadata.xml files
    """

    url = f"{ url }/api/maven/calculateMetadata/{ destination }/{ path }?nonRecursive=false"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 username,
                                 password))

    if response.status_code == 200:
        print(f"Every metadata.xml under {destination}/{path} were successfully updated\n")
    else:
        print(response.text)
        print(f"Something went wrong while updating every metadata.xml under {destination}/{path} successfully updated\n")


def copy_item(url, username, password,
              srcRepoKey, srcFilePath,
              targetRepoKey, targetFilePath,
              dryRun, suppressLayout, failFast):
    """
        Copy will update items between two repositories
        then update the metadata.xml
    """

    url = f"{ url }/api/copy/{ srcRepoKey }{ srcFilePath }?to=/{ targetRepoKey}/{ targetFilePath }&dry={ dryRun }&suppressLayout={ suppressLayout} 0&failFAst={ failFast }"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 username,
                                 password))
    j = response.json()

    print(url)
    print(j)

    for result in j['messages']:
        print(f"{result['message']}")

    print("\n")


def get_directories(url, username, password, repository, path, version):
    """
        get_directories tries to guess,
        based on a path and a version,
        which items will need to be copied
    """

    directories = []

    payload = f'''items.find({{"$and":[{{"repo":{{"$eq": "{ repository }"}}}},{{"path":{{"$match": "{ path[1:] }/*/{version}"}}}}]}}).include("repo","name","path")'''

    url = f"{ url }/api/search/aql"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 username,
                                 password),
                             data=payload)

    j = response.json()

    for result in j["results"]:
        path = "/" + result["path"]
        if path not in directories:
            directories.append(path)

    return directories


def is_directory_exist(url, username, password, repository, directory):
    """
        is_directory_exist query a maven repository
        to see if a directory already exist
    """
    url = url + '/api/storage/' + repository + directory

    response = requests.get(url,
                            auth=requests.auth.HTTPBasicAuth(
                                username,
                                password))

    if response.status_code != 200:
        return False

    return response.status_code == 200


def is_alive(url):
    """
        is_alive test if a maven repository is reachable based on a ping test
    """
    url = url + '/api/system/ping'

    response = requests.get(url)

    return response.status_code == 200


def move_item(url, username, password,
              srcRepoKey, srcFilePath,
              targetRepoKey, targetFilePath,
              dryRun, suppressLayout, failFast):
    """
        Move will move items between two repositories
        then update the metadata.xml.
        ! Items are removed from the source repository
    """

    url = f"{ url }/api/move/{ srcRepoKey }{ srcFilePath }?to=/{ targetRepoKey}/{ targetFilePath }&dry={ dryRun }&suppressLayout={ suppressLayout} 0&failFAst={ failFast }"

    response = requests.post(url,
                             auth=requests.auth.HTTPBasicAuth(
                                 username,
                                 password))
    j = response.json()

    print(url)
    print(j)

    for result in j['messages']:
        print(f"{result['message']}")

    print("\n")


def promote_item(args):
    """
        Promote item from one repository to another for a specific version
    """
    if len(args.groupID) == 0:
        directories = get_directories(args.url,
                                      args.username,
                                      args.password,
                                      args.source,
                                      "/org/jenkins-ci/main",
                                      args.version)
    else:
        for i in range(len(args.groupID)):
            args.groupID[i] = args.groupID[i] + "/" + args.version

        directories = args.groupID

    print(f"Following directories will be promoted: \n{directories}\n\n")

    dryrun = int(args.dry_run)

    if not is_alive(args.url):
        print(f"{ args.url } not reachable")
        sys.exit(2)

    api_version = get_api_version(args.url,
                                  args.username,
                                  args.password)

    print(f"Artifactory version: {api_version}\n")

    for index, directory in enumerate(directories, start=1):
        src_file_path = directory
        target_file_path = re.sub("/" + args.version + "$", '', directory)

        print(f"[{index}/{len(directories)}] - {src_file_path}")

        if not is_directory_exist(args.url,
                                  args.username,
                                  args.password,
                                  args.destination,
                                  directory):
            print(f"Planning to {args.mode} '{directory}' from { args.source } to { args.destination }\n")

            if args.mode == "copy":
                copy_item(args.url,
                          args.username,
                          args.password,
                          args.source,
                          src_file_path,
                          args.destination,
                          target_file_path,
                          dryrun,
                          0,
                          1)
            elif args.mode == "move":
                move_item(args.url,
                          args.username,
                          args.password,
                          args.source,
                          src_file_path,
                          args.destination,
                          target_file_path,
                          dryrun,
                          0,
                          1)
        else:
            print(f"\nAlready exist on { args.destination }\n")


def promote_repository(args):
    """
        Promote full repository content from source to destination
    """

    dryrun = int(args.dry_run)

    if not is_alive(args.url):
        print(f"{ args.url } not reachable")
        sys.exit(2)

    api_version = get_api_version(args.url,
                                  args.username,
                                  args.password)

    print(f"Artifactory version: {api_version}\n")

    print(f"Planning to {args.mode} { args.source } to { args.destination }\n")

    if args.mode == "copy":
        copy_item(args.url,
                  args.username,
                  args.password,
                  args.source, "/",
                  args.destination, "/",
                  dryrun, 0, 1)
    elif args.mode == "move":
        move_item(args.url,
                  args.username,
                  args.password,
                  args.source, "/",
                  args.destination, "/",
                  dryrun, 0, 1)

    calculate_metadata(args.url,
                       args.username,
                       args.password,
                       args.destination,
                       "")


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="subparser")

    repo_parser = subparsers.add_parser("repository",
                                        help="Maven repository promotion")

    repo_parser.add_argument("--source",
                             required=True,
                             help="Specify source repository")

    repo_parser.add_argument("--destination",
                             required=True,
                             help="Specify target repository")

    repo_parser.add_argument("--username",
                             required=True,
                             help="Set maven repository username repository")

    repo_parser.add_argument("--password",
                             required=True,
                             help="Set maven repository username repository")

    repo_parser.add_argument("--url",
                             default="https://repo.jenkins-ci.org",
                             required=True,
                             help="Set maven repository url")

    repo_parser.add_argument("--dry_run",
                             help="Don't copy items",
                             action="store_true")
    repo_parser.add_argument("-m", "--mode", choices=["move", "copy"],
                             default="copy",
                             help="Method uses to promote items [copy]")

    item_parser = subparsers.add_parser("item",
                                        help="Maven repository item promotion")

    item_parser.add_argument("version",
                             help="Specify version that need to be promoted")
    item_parser.add_argument("--dry_run",
                             help="Don't copy items",
                             action="store_true")
    item_parser.add_argument("-m", "--mode", choices=["move", "copy"],
                             default="copy",
                             help="Method uses to promote items [copy]")
    item_parser.add_argument("-g", "--groupID",
                             default=[], action='append',
                             help="Method uses to promote items")
    item_parser.add_argument("--source",
                             required=True,
                             help="Specify source repository")

    item_parser.add_argument("--destination",
                             required=True,
                             help="Specify target repository")

    item_parser.add_argument("--username",
                             required=True,
                             help="Set maven repository username repository")

    item_parser.add_argument("--password",
                             required=True,
                             help="Set maven repository username repository")

    item_parser.add_argument("--search",
                             default="/org/jenkins-ci/main",
                             required=False,
                             help="If no --groupID are provided then it search for items under this path that have a valid version")

    item_parser.add_argument("--url",
                             default="https://repo.jenkins-ci.org",
                             help="Set maven repository url")

    args = parser.parse_args()

    if args.subparser == 'item':
        promote_item(args)

    elif args.subparser == 'repository':
        promote_repository(args)
