# Utils
## promoteMavenArtifacts.py

I couldn't find a good solution that I am happy with so I decided to add each of them and let the release maintainer select the one he prefers.
`promoteMavenArtifacts.py` can be used in three different ways

1. Copy/Move full repository content to target and then recursively update metadata.xml
Downside: it will override destination items if they already exist, this can be mitigated by not having 'delete' permission on the remote repository.
This assumption still need to be validated especially for metdata.xml

2. Copy/Move every item for a specific  version under a specific path
 Thre 
Downside: There is a risk to copy/move unwanted items if it matches the version that needs to be copied.
 
3. Copy/Move every specific item for groupIDs provided by parameters
Downside: We have to manually maintain the list of item that needs to be promoted

### Every item for a specific version

```
      ./utils/promoteMavenArtifacts.py item --url https://repo.jenkins-ci.org --username username --password xxx  --source releases  --destination sandbox --search '/org/jenkins-ci/main' 2.224
        Following directories will be promoted:
        ['/org/jenkins-ci/main/cli/2.224', '/org/jenkins-ci/main/jenkins-bom/2.224', '/org/jenkins-ci/main/jenkins-core/2.224', '/org/jenkins-ci/main/jenkins-parent/2.224', '/org/jenkins-ci/main/jenkins-war/2.224']


        Artifactory version: 6.18.1

        [1/5] - /org/jenkins-ci/main/cli/2.224

        Already exist on sandbox

        [2/5] - /org/jenkins-ci/main/jenkins-bom/2.224

        Already exist on sandbox

        [3/5] - /org/jenkins-ci/main/jenkins-core/2.224

        Already exist on sandbox

        [4/5] - /org/jenkins-ci/main/jenkins-parent/2.224

        Already exist on sandbox

        [5/5] - /org/jenkins-ci/main/jenkins-war/2.224

        Planning to copy '/org/jenkins-ci/main/jenkins-war/2.224'
                  from releases to olblak-sandbox


        https://repo.jenkins-ci.org/api/copy/releases/org/jenkins-ci/main/jenkins-war/2.224?to=/sandbox//org/jenkins-ci/main/jenkins-war&dry=0&suppressLayout=0 0&failFAst=1
        {'messages': [{'level': 'INFO', 'message': 'copying releases:org/jenkins-ci/main/jenkins-war/2.224 to sandbox:org/jenkins-ci/main/jenkins-war completed successfully, 8 artifacts and 1 folders were copied'}]}
        copying releases:org/jenkins-ci/main/jenkins-war/2.224 to sandbox:org/jenkins-ci/main/jenkins-war completed successfully, 8 artifacts and 1 folders were copied
```

### Full repository content
```
 ./utils/promoteMavenArtifacts.py repository --url https://repo.jenkins-ci.org --username username --password password  --source source  --destination sandbox
Artifactory version: 6.18.1

Planning to copy source to sandbox


https://repo.jenkins-ci.org/api/copy/source/?to=/sandbox//&dry=0&suppressLayout=0 0&failFAst=1
{'messages': [{'level': 'INFO', 'message': 'copying source: to sandbox: completed successfully, 213 artifacts and 31 folders were copied'}]}
copying source: to sandbox: completed successfully, 213 artifacts and 31 folders were copied

Every metadata.xml under sandbox/ were successfully updated

```

### Specified item for a specific version

```
      ./utils/promoteMavenArtifacts.py item --url https://repo.jenkins-ci.org --username username --password xxx  --source releases  --destination sandbox --groupID '/org/jenkins-ci/main/cli' 2.224

        Artifactory version: 6.18.1

        [1/1] - /org/jenkins-ci/main/cli/2.224

        Already exist on sandbox


As suggested in the security profile, different profiles can have different behaviors.
