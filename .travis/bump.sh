#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..
OLD_VERSION="${1}"
NEW_VERSION="${2}"

echo "--> Clean VersionBump"
cd Utils/VersionBump && rm -rf .build && swift build
cd $SCRIPT_DIR/..
echo "--> Bumping version from ${OLD_VERSION} to ${NEW_VERSION}"
./Utils/VersionBump/.build/debug/VersionBump ${OLD_VERSION} ${NEW_VERSION}