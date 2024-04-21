#!/bin/bash

version_input=$1

if [ -z "$version_input" ]; then
  echo "Please enter a version to bump, e.g. 2.452"
  exit 1
fi

git checkout stable-${version_input}
file="profile.d/stable"
last_line=$(tail -n 1 $file)
version=$(echo $last_line | cut -d'=' -f2)
IFS='.' read -ra version_parts <<< "$version"
version_parts[2]=$((version_parts[2] + 1))

if [ "${version_parts[2]}" -eq 4 ]; then
  echo "Warning: You are about to bump from .3 to .4. Are you sure you want to continue?"
  read
fi

new_version="${version_parts[0]}.${version_parts[1]}.${version_parts[2]}"

sed -i'' -e '$d' $file
echo "JENKINS_VERSION=$new_version" >> $file
git add $file
git commit -m "Bump LTS version from $version to $new_version"
git push
git checkout master
