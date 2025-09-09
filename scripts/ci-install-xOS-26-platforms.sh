#!/bin/bash

# This script installs required platform simulators for Xcode 26

# GH actions doesn't include the beta simulators because according to them they cause too many problems: https://github.com/actions/runner-images/issues/12904#issuecomment-3242706088
# Therefore we have manually downloaded them and now install them here as suggested in the comment.
# Once GH actions includes the beta simulators, we can should remove this script.

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

log_notice "Installing required platform simulators for Xcode 26"

# Parse named arguments
PLATFORMS=""

usage() {
    echo "Usage: $0 --platforms <platform1,platform2,...>"
    echo "  Available platforms: iOS,tvOS,visionOS,watchOS"
    echo "  Example: $0 --platforms iOS,tvOS,visionOS,watchOS"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$PLATFORMS" ]; then
    echo "Error: --platforms argument is required"
    usage
fi

# Split platforms by comma
IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"

for platform in "${PLATFORM_ARRAY[@]}"; do
    case "$platform" in
        "iOS")
            begin_group "Installing iOS 26.0 simulator"
            xcodebuild -downloadPlatform iOS -quiet || {
                log_warning "Failed to download iOS platform, continuing..."
            }
            end_group
            ;;
        "tvOS")
            begin_group "Installing tvOS 26.0 simulator"
            xcodebuild -downloadPlatform tvOS -quiet || {
                log_warning "Failed to download tvOS platform, continuing..."
            }
            end_group
            ;;
        "visionOS")
            begin_group "Installing visionOS 26.0 simulator"
            xcodebuild -downloadPlatform visionOS -quiet || {
                log_warning "Failed to download visionOS platform, continuing..."
            }
            end_group
            ;;
        "watchOS")
            begin_group "Installing watchOS 26.0 simulator"
            xcodebuild -downloadPlatform watchOS -quiet || {
                log_warning "Failed to download watchOS platform, continuing..."
            }
            end_group
            ;;
        *)
            log_warning "Unknown platform: $platform, skipping..."
            ;;
    esac
done

log_notice "Platform installation completed"

begin_group "List Available Simulators"
xcrun simctl list || true
end_group
