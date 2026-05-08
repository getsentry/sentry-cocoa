#!/bin/bash
set -euo pipefail

# This script is used to verify the checksum of the static and dynamic xcframeworks in Package.swift
# and the last-release-runid in .github/last-release-runid.
# It is used to verify the outputs of the update-package-sha.sh script.

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify the checksums of xcframework zips in Package.swift files and the
last-release-runid. Used to validate the outputs of update-package-sha.sh.

OPTIONS:
    --static-checksum <sha256>                          Expected Sentry-Static checksum (required)
    --dynamic-checksum <sha256>                         Expected Sentry-Dynamic checksum (required)
    --dynamic-with-arm64e-checksum <sha256>             Expected Sentry-Dynamic-WithARM64e checksum (required)
    --without-uikit-or-appkit-checksum <sha256>         Expected Sentry-WithoutUIKitOrAppKit checksum (required)
    --without-uikit-or-appkit-with-arm64e-checksum <sha256>  Expected Sentry-WithoutUIKitOrAppKit-WithARM64e checksum (required)
    --last-release-runid <id>                           Expected GitHub Actions run ID (required)

EOF
    exit 1
}

# Parse command line arguments
EXPECTED_STATIC_CHECKSUM=""
EXPECTED_DYNAMIC_CHECKSUM=""
EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM=""
EXPECTED_WITHOUT_UIKIT_OR_APPKIT_CHECKSUM=""
EXPECTED_WITHOUT_UIKIT_OR_APPKIT_WITH_ARM64E_CHECKSUM=""
EXPECTED_LAST_RELEASE_RUNID=""

while [[ $# -gt 0 ]]; do
    case $1 in
    --static-checksum)
        EXPECTED_STATIC_CHECKSUM="$2"
        shift 2
        ;;
    --dynamic-checksum)
        EXPECTED_DYNAMIC_CHECKSUM="$2"
        shift 2
        ;;
    --dynamic-with-arm64e-checksum)
        EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM="$2"
        shift 2
        ;;
    --without-uikit-or-appkit-checksum)
        EXPECTED_WITHOUT_UIKIT_OR_APPKIT_CHECKSUM="$2"
        shift 2
        ;;
    --without-uikit-or-appkit-with-arm64e-checksum)
        EXPECTED_WITHOUT_UIKIT_OR_APPKIT_WITH_ARM64E_CHECKSUM="$2"
        shift 2
        ;;
    --last-release-runid)
        EXPECTED_LAST_RELEASE_RUNID="$2"
        shift 2
        ;;
    *)
        log_error "Unknown option: $1"
        usage
        ;;
    esac
done

# Validate required arguments
if [ -z "$EXPECTED_STATIC_CHECKSUM" ]; then
    log_error "--static-checksum is required"
    usage
fi

if [ -z "$EXPECTED_DYNAMIC_CHECKSUM" ]; then
    log_error "--dynamic-checksum is required"
    usage
fi

if [ -z "$EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM" ]; then
    log_error "--dynamic-with-arm64e-checksum is required"
    usage
fi

if [ -z "$EXPECTED_WITHOUT_UIKIT_OR_APPKIT_CHECKSUM" ]; then
    log_error "--without-uikit-or-appkit-checksum is required"
    usage
fi

if [ -z "$EXPECTED_WITHOUT_UIKIT_OR_APPKIT_WITH_ARM64E_CHECKSUM" ]; then
    log_error "--without-uikit-or-appkit-with-arm64e-checksum is required"
    usage
fi

if [ -z "$EXPECTED_LAST_RELEASE_RUNID" ]; then
    log_error "--last-release-runid is required"
    usage
fi

# Find all Package.swift and Package@swift-*.swift files
PACKAGE_FILES=$(find . -maxdepth 1 -name "Package.swift" -o -name "Package@swift-*.swift" | sort)

if [ -z "$PACKAGE_FILES" ]; then
    log_error "No Package.swift or Package@swift-*.swift files found"
    exit 1
fi

# Verify checksums in each Package file
for package_file in $PACKAGE_FILES; do
    log_info "Verifying checksums in $package_file"
    
    # Verify static checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Static" "$package_file" | cut -d '"' -f 2)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_STATIC_CHECKSUM" ]; then
        log_error "Expected static checksum to be $EXPECTED_STATIC_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi
    
    # Verify dynamic checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Dynamic" "$package_file" | cut -d '"' -f 2 | head -n 1)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_DYNAMIC_CHECKSUM" ]; then
        log_error "Expected dynamic checksum to be $EXPECTED_DYNAMIC_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi

    # Verify dynamic with arm64e checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Dynamic-WithARM64e" "$package_file" | cut -d '"' -f 2)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM" ]; then
        log_error "Expected checksum to be $EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi

    # Verify without uikit or appkit checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-WithoutUIKitOrAppKit" "$package_file" | cut -d '"' -f 2 | head -n 1)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_WITHOUT_UIKIT_OR_APPKIT_CHECKSUM" ]; then
        log_error "Expected checksum to be $EXPECTED_WITHOUT_UIKIT_OR_APPKIT_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi

    # Verify without uikit or appkit with arm64e checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-WithoutUIKitOrAppKit-WithARM64e" "$package_file" | cut -d '"' -f 2)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_WITHOUT_UIKIT_OR_APPKIT_WITH_ARM64E_CHECKSUM" ]; then
        log_error "Expected checksum to be $EXPECTED_WITHOUT_UIKIT_OR_APPKIT_WITH_ARM64E_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi
    
    log_info "✓ All checksums verified in $package_file"
done



log_info "Verify last-release-runid"
LAST_RELEASE_RUNID=$(cat .github/last-release-runid)
if [ "$LAST_RELEASE_RUNID" != "$EXPECTED_LAST_RELEASE_RUNID" ]; then
    log_error "Expected last-release-runid to be $EXPECTED_LAST_RELEASE_RUNID but got $LAST_RELEASE_RUNID"
    exit 1
fi
