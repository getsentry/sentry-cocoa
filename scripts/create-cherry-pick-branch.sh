#!/bin/bash

#Creates a new branch from given tag and cherry pick commit.
#This helps to make a hotfix release by updating given version
#with the merge commit of a specific PR.

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
git push origin "$hotfix_branch"

echo "Hotfix branch $hotfix_branch created and pushed successfully."

