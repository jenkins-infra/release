#!/usr/bin/env bash

# List commits that belong to particular issue, not yet reported to current branch.
# In the output, each commit has a number of weekly releases it has been released in

if [ "$(git rev-parse --abbrev-ref HEAD)" == "master" ]; then
    echo >&2 "You are on a master branch"
    exit 1
fi

master=$(git log --oneline master --grep "$1")
if [ "$?" -ne 0 ]; then
    echo "No matching commits on master branch" >&2
    exit 1
fi
current=$(git log --oneline --grep "$1")

today=$(date +"%Y-%m-%d")

identical=()
patch_commits=()
while read m; do
    while read c; do
        if [ -z "$c" -a -z "$m" ]; then
            # Ignore the empty line inserted in case both logs are empty
            continue;
        fi
        if [ "$c" == "$m" ]; then
            # Present in both, move to next commit
            identical+=(${c%% *})
            continue 2;
        fi
    done <<< "$current"

    # Not found in current branch
    sha=$(cut -f1 -d' ' <<< "$m")
    patch_commits+=($sha)
    # Remove trailing ~\d: https://git.vger.kernel.narkive.com/O33undVc/describe-contains-abbrev-0-sha1-doesn-t-work-as-expected
    first_release=$(git describe --contains --abbrev=0 "$sha" 2>/dev/null | sed 's/~.*//')
    if [ "$first_release" != "" ]; then
        release_date=$(git log -1 --format=%ci "$first_release" | sed 's/ .*//')
        today_epoch=$(date -j -f "%Y-%m-%d" "$today" "+%s" 2>/dev/null || date -d "$today" "+%s")
        release_epoch=$(date -j -f "%Y-%m-%d" "$release_date" "+%s" 2>/dev/null || date -d "$release_date" "+%s")
        age=$(( (today_epoch - release_epoch) / 86400 ))
        info="$first_release ($age days)"
    else
        info="Unreleased"
    fi
    echo "$info $m" | grep --color=auto "$1" # Grep again to color the output but never hide a line
done <<< "$master"

if [ ${#patch_commits[@]} -gt 0 ]; then
    echo "Unique commits on master branch: ${patch_commits[@]}"
fi

num_matches=${#identical[@]}
branch=$(git rev-parse --abbrev-ref HEAD)
echo "Commits present on master and $branch branch: $num_matches"
if [ $num_matches -gt 0 ]; then
    echo "${identical[@]}"
fi
