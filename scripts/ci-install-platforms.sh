#!/bin/bash

# This script installs required platform simulators for Xcode 26
# The platforms need to be downloaded from Xcode Components before they can be used

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

# List available runtimes after installation
begin_group "Available simulator runtimes after installation"
xcrun simctl list runtimes || true
end_group