#!/bin/bash

# This script downloads platform simulators that are not preinstalled with the active Xcode version.
#
# Primary use cases:
# 1. Downloading beta platforms for Xcode 26 (iOS 26.1, tvOS 26.1, etc.)
# 2. Downloading older iOS versions on newer Xcode (e.g., iOS 16.4 on Xcode 26.1)
#
# Note: GitHub Actions doesn't include beta simulators by default because they can cause issues.
# See: https://github.com/actions/runner-images/issues/12904#issuecomment-3242706088

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

log_notice "Downloading required platform simulators for the active Xcode version"

# Parse named arguments
PLATFORMS=""
OS_VERSION=""

usage() {
    echo "Usage: $0 --platforms <platform1,platform2,...> --os-version <os_version>"
    echo "  Available platforms: iOS,tvOS,visionOS,watchOS"
    echo "  OS version: Version to download (e.g., 26.1 for beta, 16.4 for older iOS)"
    echo "  Example: $0 --platforms iOS --os-version 26.1"
    echo "  Example: $0 --platforms iOS --os-version 16.4"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --os-version)
            OS_VERSION="$2"
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
            begin_group "Installing iOS $OS_VERSION platform"
            xcodebuild -downloadPlatform iOS -buildVersion "$OS_VERSION" -quiet || {
                log_warning "Failed to download iOS platform, continuing..."
            }
            end_group
            ;;
        "tvOS")
            begin_group "Installing tvOS $OS_VERSION platform"
            xcodebuild -downloadPlatform tvOS -buildVersion "$OS_VERSION" -quiet || {
                log_warning "Failed to download tvOS platform, continuing..."
            }
            end_group
            ;;
        "visionOS")
            begin_group "Installing visionOS $OS_VERSION platform"
            xcodebuild -downloadPlatform visionOS -buildVersion "$OS_VERSION" -quiet || {
                log_warning "Failed to download visionOS platform, continuing..."
            }
            end_group
            ;;
        "watchOS")
            begin_group "Installing watchOS $OS_VERSION platform"
            xcodebuild -downloadPlatform watchOS -buildVersion "$OS_VERSION" -quiet || {
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
xcrun simctl list
end_group
