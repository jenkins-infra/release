# Toolkit for LTS backporting.

A set of tools to automate tedious and/or error prone LTS maintaining activities. Command outputs may contain reminders and warnings so it is worth reading.

## Usage

### Create new LTS line

Each LTS line has its backports in separate git branch named 'stable-X.Y'. To create it run:

`init-lts-line <baseline_version>`

There is a couple of manual tasks that needs to follow described in the output.

### Backporting

Process through [LTS Candidates](https://issues.jenkins.io/issues/?filter=12146) and update label `lts-candidate` to `${VERSION}-fixed` or `${VERSION}-rejected`. See `lts-candidate-stats <next_lts_version>` for status report.

#### Identify issue commits

`list-issue-commits <jira_id>` can be used to identify what (properly labeled) commits are

- Common for master branch and current branch (no need to backport)
- On master branch only (needs to be backported). The script reports the number of weekly releases the commit is part of in parentheses.

Note it is never 100% bullet proof as there might be commits that are part of the fix yet are not labeled as such. Reviewing the JIRA and/or the Pull Request is often needed anyway. Longer branches are better cherry picked by merge commits.

The commits are backported using `git cherry-pick -x <sha>` so the original commit is referenced.
