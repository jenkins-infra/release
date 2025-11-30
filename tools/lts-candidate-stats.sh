#!/usr/bin/env bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./lts-candidate-stats.sh <version>" >&2
    echo "       ./lts-candidate-stats.sh 2.528.1" >&2
    exit 1
fi

label_version_dot="$1"

OWNER=jenkinsci
REPO=jenkins
SEARCH_LIMIT=100

export GH_PAGER=cat

targetVersion=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout --batch-mode)
if [[ "$targetVersion" != *"$version"* ]]; then
    echo "The previous version does not appear to be released yet: $targetVersion" >&2
    exit 1
fi

git fetch upstream master:master
echo "Latest core version: $(git describe master --abbrev=0)"

fetch_issues() {
    gh search issues --state closed --owner $OWNER --repo $REPO --limit $SEARCH_LIMIT --label "${label_version_dot}-fixed" --json url --template 'Fixed:
{{range .}}{{tablerow (printf "- %v" .url | autocolor "green")}}{{end}}'
    gh search prs --state closed --owner $OWNER --repo $REPO --limit $SEARCH_LIMIT --label "${label_version_dot}-fixed" --json url --template '{{range .}}{{tablerow (printf "- %v" .url | autocolor "green")}}{{end}}'
}

fetch_postponed_candidates() {
    gh search issues --state closed --owner $OWNER --repo $REPO --limit $SEARCH_LIMIT --label "${label_version_dot}-rejected" --json url --template 'Postponed:
{{range .}}{{tablerow (printf "- %v" .url | autocolor "green")}}{{end}}'
    gh search prs --state closed --owner $OWNER --repo $REPO --limit $SEARCH_LIMIT --label "${label_version_dot}-rejected" --json url --template '{{range .}}{{tablerow (printf "- %v" .url | autocolor "green")}}{{end}}'
}

fetch_issues
echo ""
fetch_postponed_candidates
