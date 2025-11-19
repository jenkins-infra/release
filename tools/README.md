# Toolkit for LTS backporting.

A set of tools to automate tedious and/or error prone LTS maintaining activities. Command outputs may contain reminders and warnings so it is worth reading.

## Usage

### Create new LTS line

Each LTS line has its backports in separate git branch named 'stable-X.Y'. To create it run:

`init-lts-line <baseline_version>`

There is a couple of manual tasks that needs to follow described in the output.

### Backporting

Process through [LTS Candidates](https://github.com/jenkinsci/jenkins/issues?q=is%3Aclosed%20label%3Alts-candidate) and update label `lts-candidate` to `${VERSION}-fixed` or `${VERSION}-rejected`. See `./lts-candidate-stats.sh <next_lts_version>` for status report.

#### Identify issue commits

For issues look at the PR that closed the issue or is linked to the issue.
For pull requests look at the commit that was merged closing the pull request.
