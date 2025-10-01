#!/usr/bin/env bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./lts-candidate-stats.sh <version>" >&2
    echo "       ./lts-candidate-stats.sh 2.528.1" >&2
    exit 1
fi

label_version_dot="$1"

targetVersion=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout --batch-mode)
if [[ "$targetVersion" != *"$version"* ]]; then
    echo "The previous version does not appear to be released yet: $targetVersion" >&2
    exit 1
fi

git fetch upstream master:master
echo "Latest core version: $(git describe master --abbrev=0)"

fetch_issues() {
    local url="$1"
    curl -s "$url" | \
    awk '
    /<item/ {initem=1; title=""; link=""}
    /<\/item>/ {if (title && link) print "- " title " (" link ")"; initem=0}
    initem && /<title>/ {sub(/.*<title>/,""); sub(/<\/title>.*/,""); title=$0}
    initem && /<link>/ {sub(/.*<link>/,""); sub(/<\/link>.*/,""); link=$0}
    '
}

fetch_postponed_candidates() {
    local url="$1"
    curl -s "$url" | \
    awk -v rejected="${label_version_dot}-rejected" '
    /<item/ {initem=1; title=""; link=""; label=""}
    /<\/item>/ {
        if (title && link && label ~ rejected)
            print "- " title " (" link ")";
        initem=0
    }
    initem && /<title>/ {sub(/.*<title>/,""); sub(/<\/title>.*/,""); title=$0}
    initem && /<link>/ {sub(/.*<link>/,""); sub(/<\/link>.*/,""); link=$0}
    initem && /<label>.*<\/label>/ {
        sub(/.*<label>/,"");
        sub(/<\/label>.*/,"");
        if ($0 ~ rejected) {
            label=$1;
        }
    }
    '
}

echo -e "\nFixed:\n------------------"
fetch_issues "https://issues.jenkins.io/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml?tempMax=1000&jqlQuery=labels%3D${label_version_dot}-fixed&field=title&field=link"

echo -e "\nPostponed:\n------------------"
fetch_postponed_candidates "https://issues.jenkins.io/sr/jira.issueviews:searchrequest-xml/12146/SearchRequest-12146.xml?tempMax=1000&field=title&field=link&field=labels"
