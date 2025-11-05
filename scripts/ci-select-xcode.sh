#!/bin/bash

# For available Xcode versions see:
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
# - https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

XCODE_VERSION="${1}"

# We prefer this over calling `sudo xcode-select` because it will fail if the Xcode version
# is not installed. Also xcodes is preinstalled on the GH runners.
sudo xcodes select "$XCODE_VERSION"
swiftc --version


begin_group "List Available Simulators"

# On GH actions this command should cause the GH actions to recache and detect missing runtimes, as pointed out in
# https://github.com/actions/runner-images/issues/12948#issuecomment-3248563014
# The command is fast and should avoids problems we had with GH actions not having specific simulators installed 
# see https://github.com/getsentry/sentry-cocoa/pull/6053.

start_time=$(date +%s)

sudo xcrun simctl list

end_time=$(date +%s)
xcrun_simctl_list_duration=$((end_time - start_time))

end_group

# We want to log the duration after the group, because otherwise it's hidden at the end of the group.
echo "List Available Simulators completed in ${xcrun_simctl_list_duration} seconds"
