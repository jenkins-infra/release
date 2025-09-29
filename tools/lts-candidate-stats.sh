#!/usr/bin/env bash

set -e

PREFIX="https://issues.jenkins.io/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml?tempMax=1000&jqlQuery="

if [ "$#" -ne 1 ]; then
    echo "Usage: lts-candidate-stats <version>" >&2
    exit 1
fi

version="$1"
label_version_dash="${version//./-}"
label_version_dot="$version"

targetVersion=$(echo 'VERSION=${project.version}' | mvn help:evaluate | sed -n 's/^VERSION=//p')
if [[ "$targetVersion" != *"$version"* ]]; then
    echo "The previous version does not appear to be released yet: $targetVersion" >&2
    exit 1
fi

git fetch upstream master:master
echo "Latest core version: $(git describe master --abbrev=0)"

fetch_issues() {
    local url="$1"
    curl -s "$url" | xmllint --xpath "//*[local-name()='item']" - 2>/dev/null | \
    awk '
    /<item/ {initem=1; title=""; link=""}
    /<\/item>/ {if (title && link) print "- " title " (" link ")"; initem=0}
    initem && /<title>/ {sub(/.*<title>/,""); sub(/<\/title>.*/,""); title=$0}
    initem && /<link>/ {sub(/.*<link>/,""); sub(/<\/link>.*/,""); link=$0}
    '
}

fetch_postponed_candidates() {
    local url="$1"
    curl -s "$url" | xmllint --xpath "//*[local-name()='item']" - 2>/dev/null | \
    awk -v postponed="${label_version_dash}-postponed" -v cand="lts-candidate" '
    /<item/ {initem=1; title=""; link=""; labels=""}
    /<\/item>/ {
        if (title && link && !(labels ~ postponed && labels ~ cand))
            print "- " title " (" link ")";
        initem=0
    }
    initem && /<title>/ {sub(/.*<title>/,""); sub(/<\/title>.*/,""); title=$0}
    initem && /<link>/ {sub(/.*<link>/,""); sub(/<\/link>.*/,""); link=$0}
    initem && /<labels>/ {sub(/.*<labels>/,""); sub(/<\/labels>.*/,""); labels=$0}
    '
}

echo -e "\nFixed:\n------------------"
fetch_issues "${PREFIX}labels+in+%28${label_version_dash}-fixed%29"
fetch_issues "${PREFIX}labels+in+%28${label_version_dot}-fixed%29"

echo -e "\nPostponed:\n------------------"
fetch_postponed_candidates "https://issues.jenkins.io/sr/jira.issueviews:searchrequest-xml/12146/SearchRequest-12146.xml?tempMax=1000"
