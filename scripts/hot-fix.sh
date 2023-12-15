#!/bin/bash

#Creates a hotfix branch from given tag and commit
#run this from sentry-cocoa root directory

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <current version> <new version> <commit hash>"
    exit 1
fi

# Assign command-line arguments to variables
tag="$1"
version="$2"
commit_hash="$3"

# Define the hotfix branch name
hotfix_branch="hotfix/$version"

git checkout "tags/$tag"
git checkout -b "$hotfix_branch"
git cherry-pick "$commit_hash"
git commit -m "Merge commit $commit_hash into $hotfix_branch"
git push origin "$hotfix_branch"

echo "Hotfix branch $hotfix_branch created and pushed successfully."

