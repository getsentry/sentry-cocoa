#!/bin/bash
set -euo pipefail

TO_REPLACE="${1}"
FILE="${2}"

# replace / with \/ as branches can contain /
CURRENT_BRANCH=$(git branch --show-current | sed 's/\//\\\//g')
sed -i "" -e "s/$TO_REPLACE/${CURRENT_BRANCH}/g" $FILE
