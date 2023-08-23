---
name: "🚤 New LTS release checklist"
labels: lts-checklist
about: Track work required for a new LTS release
---

# Next LTS release

More information about the release process is available on the [release guide](https://github.com/jenkins-infra/release/blob/master/docs/releases.md).

## Release Lead

<!-- 
The release lead is the person who makes sure that all steps are completed
Not necessarily the person doing all the work

This role should rotate between LTS releases
-->

@<github-username of release lead>

## Prep work

- [ ] LTS baseline discussed and selected in the [Jenkins developers mailing list](https://groups.google.com/g/jenkinsci-dev).

- [ ] Create or update release branch in [jenkinsci/jenkins](https://github.com/jenkinsci/jenkins), e.g. `stable-2.387`, use the [init-lts-line](https://github.com/jenkins-infra/release/blob/master/tools/init-lts-line) script or carry out the equivalent steps therein.

- [ ] Create or update release branch in [jenkins-infra/release](https://github.com/jenkins-infra/release), e.g. `stable-2.387`.
  - [ ] Modify the `RELEASE_GIT_BRANCH` and `JENKINS_VERSION` values in the environment file (`profile.d/stable`) to match the release.
  - [ ] Modify the `PACKAGING_GIT_BRANCH` value in the packaging script (`Jenkinsfile.d/core/package`) to match the release.
  - For more info, refer to [stable](https://github.com/jenkins-infra/release#stable).

- [ ] Create or update release branch in [jenkinsci/packaging](https://github.com/jenkinsci/packaging), e.g. `stable-2.387`.

- [ ] Create a pull request to update [bom](https://github.com/jenkinsci/bom) to the weekly version that will be the base of the release line (and strike this out for new point release).
      Assure that the [bom-weekly version number](https://github.com/jenkinsci/bom/blob/master/sample-plugin/pom.xml#L17) is already testing the base of the release line or a version newer than the base of the release line.

- [ ] Review Jira and GitHub pull requests for additional LTS candidates, adding the `lts-candidate` label, and ensure that all tickets are resolved in Jira.

- [ ] Send a backporting announcement email to the [jenkinsci-dev](https://groups.google.com/g/jenkinsci-dev) mailing list, using the [default](https://groups.google.com/g/jenkinsci-dev/c/sZY2WXoWLWM) template.
Remember to exchange the LTS version, release date and Jira URLs.

- [ ] Update Jira labels for [lts-candidate issues](https://issues.jenkins.io/issues/?filter=12146), either add `2.387.2-fixed` and remove `lts-candidate` or add `2.387.2-rejected`, and retain `lts-candidate`.

- [ ] Backport changes, run the [list-issue-commits script](https://github.com/jenkins-infra/release/blob/master/tools/list-issue-commits) to locate commits via Jira ID, some manual work is required to locate them if the issue ID wasn't present at merge time, backport with `git cherry-pick -x $commit`.

- [ ] Open backporting PR with `into-lts` label and summary of changes in description from [lts-candidate-stats script](https://github.com/jenkins-infra/release/blob/master/tools/lts-candidate-stats) and:
  - [ ] the selected [Jira lts-candidates](https://issues.jenkins-ci.org/issues/?filter=12146).
  - [ ] possible LTS candidates in the [release](https://github.com/jenkins-infra/release/issues?q=is%3Aclosed+label%3Alts-candidate+) repository.
  - [ ] possible LTS candidates in the [packaging](https://github.com/jenkinsci/packaging/issues?q=is%3Aclosed+label%3Alts-candidate) repository.

- [ ] Review ATH and bom integration tests results.

- [ ] Update the dependabot branch target in [jenkinsci/jenkins](https://github.com/jenkinsci/jenkins/blob/bacb1c8d2899d161a0995d69ab5c932ca4d3ab30/.github/dependabot.yml#L56) to the new stable branch.

- [ ] Prepare [LTS changelog](https://www.jenkins.io/changelog-stable/) based on the [style guide](https://github.com/jenkins-infra/jenkins.io/blob/master/content/_data/changelogs/_STYLEGUIDE.adoc) using the [changelog generator](https://github.com/jenkinsci/core-changelog-generator/blob/master/README.md) - This is normally done by the docs team, ask in [gitter](https://app.gitter.im/#/room/#jenkins/docs:matrix.org).

- [ ] Prepare [LTS upgrade guide](https://www.jenkins.io/doc/upgrade-guide/) based on [previous upgrade guides](https://github.com/jenkins-infra/jenkins.io/tree/master/content/_data/upgrades)  - This is normally done by the docs team, ask in [gitter](https://app.gitter.im/#/room/#jenkins/docs:matrix.org).

## RC creation

- [ ] Merge backporting PR in [`jenkinci/jenkins`](https://github.com/jenkinsci/jenkins) using a merge commit (and do not squash).

- [ ] Retrieve the URL for the RC from the commit status (Jenkins Incrementals Publisher / Incrementals) of the last build on the stable branch (requires a passing build). Visit the `jenkins-war` URL and copy the URL of the war file, which would be something like https://repo.jenkins-ci.org/incrementals/org/jenkins-ci/main/jenkins-war/2.387.1-rc32701.b_06d9cef554c/jenkins-war-2.387.1-rc32701.b_06d9cef554c.war. If the incrementals are broken you can deploy a build from your own machine with `mvn -e clean deploy -DskipTests=true`.

- [ ] Publish a pre-release [Github release](https://github.com/jenkinsci/jenkins/releases), e.g. [sample](https://github.com/jenkinsci/jenkins/releases/tag/jenkins-2.387.1-rc) currently we don't have a changelog for RCs.

- [ ] Confirm the automatic announcement has been sent to the [jenkinsci-dev](https://groups.google.com/g/jenkinsci-dev) mailing list and [community forums](https://community.jenkins.io/c/blog/23).

- [ ] Check with security team that no security update is planned.  If a security update is planned, revise the checklist after the public pre-announcement to the [jenkinsci-advisories mailing list](https://groups.google.com/g/jenkinsci-advisories).

## LTS release

- [ ] Publish changelog (one day prior to the release in case of a security update).

- [ ] Announce the start of the LTS release process in the [#jenkins-release:matrix.org](https://matrix.to/#/#jenkins-release:matrix.org) channel.
- [ ] Run job on [release.ci.jenkins.io](https://release.ci.jenkins.io/job/core/job/stable/job/release/) if no security release for Jenkins is planned.

- [ ] Check [LTS changelog](https://www.jenkins.io/changelog-stable/) is visible on the downloads site.

- [ ] Publish [GitHub release](https://github.com/jenkinsci/jenkins/releases) pointing to LTS changelog, [sample](https://github.com/jenkinsci/jenkins/releases/tag/jenkins-2.387.1).

- [ ] Confirm [Datadog checks](https://p.datadoghq.com/sb/0Igb9a-e6849e5e019250ef5aaea3589297fe8b) are passing.

- [ ] Confirm the [Debian installer acceptance test](https://ci.jenkins.io/job/Infra/job/acceptance-tests/job/install-lts-debian-package/) is passing.
  For good measures, check the console log to confirm that the correct release package was used (e.g. search for `2.387`).

- [ ] Confirm the [Red Hat installer acceptance test](https://ci.jenkins.io/job/Infra/job/acceptance-tests/job/install-lts-redhat-rpm/) is passing.
  For good measures, check the console log to confirm that the correct release package was used (e.g. search for `2.387`).
  
- [ ] Adjust state and `Released As` of [Jira issues](https://issues.jenkins.io/) fixed in the release (see the [changelog](https://www.jenkins.io/changelog-stable) for issue links).

- [ ] Create pull request to update the `lts` Maven profile in [ATH](https://github.com/jenkinsci/acceptance-test-harness) to the newly released version

- [ ] Create a tag matching the LTS release you create in the [docker](https://github.com/jenkinsci/docker/) repository and publish a GitHub release.

- [ ] Confirm that the images are available at [Docker hub](https://hub.docker.com/r/jenkins/jenkins/tags).

- [ ] Merge the PR generated by the `jenkins-dependency-updater` bot in the [jenkinsci/helm-charts](https://github.com/jenkinsci/helm-charts) repository.

- [ ] Create a [helpdesk](https://github.com/jenkins-infra/helpdesk/issues) ticket to update `ci.jenkins.io`, `trusted.ci`, `cert.ci` and `release.ci` to the new LTS release, [example](https://github.com/jenkins-infra/helpdesk/issues/3561).
  
- [ ] Send email asking for the next release lead, [example](https://groups.google.com/g/jenkinsci-dev/c/FrUnLUXdArg/m/BfXf5INlBwAJ), dates for the next one can be found on the [Jenkins calendar](https://www.jenkins.io/events/).
