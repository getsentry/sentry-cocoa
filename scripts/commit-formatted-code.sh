#!/bin/bash
set -euo pipefail

if [[ $(git status) == *"nothing to commit"* ]]; then
    echo "Nothing to commit. All code formatted correctly."
else
    echo "Formatted some code. Going to push the changes."
    git config --global user.name 'Sentry Github Bot'
    git config --global user.email 'bot+github-bot@sentry.io'
    git commit -am "Format code"
    git push 
fi
