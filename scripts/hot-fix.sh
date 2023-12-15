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

# Create a new branch
git checkout -b "$hotfix_branch"

# Checkout the specified tag into the hotfix branch
git checkout "$tag" -b "$hotfix_branch"

# Cherry-pick the specified commit
git cherry-pick "$commit_hash"

# Commit the changes
git commit -m "Merge commit $commit_hash into $hotfix_branch"

# Push the changes to the remote repository
#git push origin "$hotfix_branch"

# Inform the user about the successful completion
echo "Hotfix branch $hotfix_branch created and pushed successfully."

