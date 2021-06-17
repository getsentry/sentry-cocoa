#!/bin/bash
set -euo pipefail

TO_REPLACE="${1}"
FILE="${2}"
CURRENT_COMMIT_HASH=$(git rev-parse HEAD)

sed -i "" -e "s/$TO_REPLACE/${CURRENT_COMMIT_HASH}/g" $FILE
