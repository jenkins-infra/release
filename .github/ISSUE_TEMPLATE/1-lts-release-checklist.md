---
name: "🥇 New LTS release checklist"
labels: lts
about: Track work required for a new LTS release
---

# Next LTS release

## Release Lead

<!-- 
The release lead is the person who makes sure that all steps are completed
Not necessarily the person doing all the work

This role should rotate between LTS releases
-->

@<github-username of release lead>

## Prep work

- [ ] LTS baseline discussed and selected in the [Jenkins developers mailing list](https://groups.google.com/g/jenkinsci-dev)

- [ ] Create or update release branch in [jenkinsci/jenkins](https://github.com/jenkinsci/jenkins), e.g. `stable-2.263`

- [ ] Create or update release branch in [jenkins-infra/release](https://github.com/jenkins-infra/release), e.g. `stable-2.263`

- [ ] Create or update release branch in [jenkinsci/packaging](https://github.com/jenkinsci/packaging), e.g. `stable-2.263`

- [ ] Create pull request to update bom to new release line (strike this out for new point release)

- [ ] Create pull request to update configuration-as-code integration tests to new release line (strike this out for new point release)

- [ ] Backporting announcement email

- [ ] Review Jira and GitHub pull requests for additional candidates

- [ ] Open backporting PR with into-lts label and summary of changes in description from script

- [ ] Review ATH, bom and configuration-as-code integration tests results

- [ ] Prepare [LTS changelog](https://www.jenkins.io/changelog-stable/) based on the [style guide](https://github.com/jenkins-infra/jenkins.io/blob/master/content/_data/changelogs/_STYLEGUIDE.adoc) using the [changelog generator](https://github.com/jenkinsci/core-changelog-generator/blob/master/README.md)

- [ ] Prepare [LTS upgrade guide](https://www.jenkins.io/doc/upgrade-guide/) based on [previous upgrade guides](https://github.com/jenkins-infra/jenkins.io/tree/master/content/_data/upgrades)

## RC creation

- [ ] Merge backporting PR in jenkinci/jenkins using a merge commit (do not squash)

- [ ] Create or update release branch in [jenkins-infra/release](https://github.com/jenkins-infra/release), e.g. `rc-stable-2.263`.

- [ ] Create or update packaging branch in [jenkinsci/packaging]([jenkinsci/packaging](https://github.com/jenkinsci/packaging)), e.g. `stable-2.263`

- [ ] Run job on [release.ci.jenkins.io](https://release.ci.jenkins.io/job/core/job/stable-rc)

- [ ] Publish [Github release](https://github.com/jenkinsci/jenkins/releases) using the GitHub changelog draft

- [ ] Send announcement email

- [ ] Check with security team that no security update is planned.  If a security update is planned, revise the checklist after the public pre-announcement to the [jenkinsci-advisories mailing list](https://groups.google.com/g/jenkinsci-advisories)

- [ ] Create draft changelog and draft upgrade guide as a jenkins.io pull request
## LTS release

- [ ] Check [LTS changelog](https://www.jenkins.io/changelog-stable/) status

- [ ] Create or update release branch in jenkins-infra/release, e.g. `stable-2.263`

- [ ] Run job on [release.ci.jenkins.io](https://release.ci.jenkins.io/blue/organizations/jenkins/core%2Fstable%2Frelease/branches/)

- [ ] Publish changelog (one day prior to the release in case of a security update)

- [ ] Publish GitHub release pointing to LTS changelog

<!--
Put an `x` into the [ ] to show you have filled the information below
Describe your issue below
-->
