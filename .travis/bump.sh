#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="${1}"

echo "--> Clean VersionBump"
cd Utils/VersionBump && swift build
cd $SCRIPT_DIR/..
echo "--> Bumping version to ${NEW_VERSION}"
./Utils/VersionBump/.build/debug/VersionBump ${NEW_VERSION}