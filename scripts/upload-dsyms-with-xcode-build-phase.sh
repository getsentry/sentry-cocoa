#!/bin/bash
set -uox pipefail

# Use this script to apply a patch so Xcode uploads the iOS-Swift's dSYMs to
# Sentry during Xcode's build phase.
# Ensure to not commit the patch file after running this script, which then contains
# your auth token.

SENTRY_AUTH_TOKEN="${1}"

# Replace revision with SHA
REPLACE="s/YOUR_AUTH_TOKEN/${SENTRY_AUTH_TOKEN}/g"
sed -i '' $REPLACE ./scripts/upload-dsyms-with-xcode-build-phase.patch

git apply ./scripts/upload-dsyms-with-xcode-build-phase.patch
