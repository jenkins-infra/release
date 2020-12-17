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

- [ ] LTS baseline selected

- [ ] LTS branch created in jenkinsci/jenkins, e.g. `stable-2.263` (strike this out for new point release)

- [ ] Create pull request to update bom to new release line (strike this out for new point release)

- [ ] Create pull request to update configuration-as-code integration tests to new release line (strike this out for new point release)

- [ ] Backporting announcement email

- [ ] Review Jira and GitHub pull requests for additional candidates

- [ ] Open backporting PR with into-lts label and summary of changes in description from script

- [ ] Review ATH, bom and configuration-as-code integration tests results

- [ ] Prepare LTS changelog

- [ ] Prepare LTS upgrade guide

## RC creation

- [ ] Merge backporting PR in jenkinci/jenkins

- [ ] Create or update release branch in jenkins-infra/release, e.g. `rc-stable-2.263`.

- [ ] Create or update packaging branch in jenkinsci/packaging, e.g. `stable-2.263`

- [ ] Run job on [release.ci.jenkins.io](https://release.ci.jenkins.io/blue/organizations/jenkins/core%2Fstable%2Frelease/branches/) # TODO update url

- [ ] Publish pre-release Github release

- [ ] Send announcement email

## LTS release

- [ ] Check LTS changelog status

- [ ] Create or update release branch in jenkins-infra/release, e.g. `stable-2.263`

- [ ] Run job on [release.ci.jenkins.io](https://release.ci.jenkins.io/blue/organizations/jenkins/core%2Fstable%2Frelease/branches/)

- [ ] Publish changelog

- [ ] Publish GitHub release pointing to LTS changelog

<!--
Put an `x` into the [ ] to show you have filled the information below
Describe your issue below
-->
