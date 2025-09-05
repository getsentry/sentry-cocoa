#!/bin/bash
set -euo pipefail

# This script is used to verify the checksum of the static and dynamic xcframeworks in Package.swift
# and the last-release-runid in .github/last-release-runid.
# It is used to verify the outputs of the update-package-sha.sh script.

# Parse command line arguments
EXPECTED_STATIC_CHECKSUM=""
EXPECTED_DYNAMIC_CHECKSUM=""
EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM=""
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
    --last-release-runid)
        EXPECTED_LAST_RELEASE_RUNID="$2"
        shift 2
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Validate required arguments
if [ -z "$EXPECTED_STATIC_CHECKSUM" ]; then
    echo "Error: --static-checksum is required"
    exit 1
fi

if [ -z "$EXPECTED_DYNAMIC_CHECKSUM" ]; then
    echo "Error: --dynamic-checksum is required"
    exit 1
fi

if [ -z "$EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM" ]; then
    echo "Error: --dynamic-with-arm64e-checksum is required"
    exit 1
fi

if [ -z "$EXPECTED_LAST_RELEASE_RUNID" ]; then
    echo "Error: --last-release-runid is required"
    exit 1
fi

# Find all Package.swift and Package@swift-*.swift files
PACKAGE_FILES=$(find . -maxdepth 1 -name "Package.swift" -o -name "Package@swift-*.swift" | sort)

if [ -z "$PACKAGE_FILES" ]; then
    echo "::error::No Package.swift or Package@swift-*.swift files found"
    exit 1
fi

# Verify checksums in each Package file
for package_file in $PACKAGE_FILES; do
    echo "Verifying checksums in $package_file"
    
    # Verify static checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Static" "$package_file" | cut -d '"' -f 2)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_STATIC_CHECKSUM" ]; then
        echo "::error::Expected static checksum to be $EXPECTED_STATIC_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi
    
    # Verify dynamic checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Dynamic" "$package_file" | cut -d '"' -f 2 | head -n 1)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_DYNAMIC_CHECKSUM" ]; then
        echo "::error::Expected dynamic checksum to be $EXPECTED_DYNAMIC_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi

    # Verify dynamic with arm64e checksum
    UPDATED_PACKAGE_SHA=$(grep "checksum.*Sentry-Dynamic-WithARM64e" "$package_file" | cut -d '"' -f 2)
    if [ "$UPDATED_PACKAGE_SHA" != "$EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM" ]; then
        echo "::error::Expected checksum to be $EXPECTED_DYNAMIC_WITH_ARM64E_CHECKSUM but got $UPDATED_PACKAGE_SHA in $package_file"
        exit 1
    fi
    
    echo "✓ All checksums verified in $package_file"
done



echo "Verify last-release-runid"
LAST_RELEASE_RUNID=$(cat .github/last-release-runid)
if [ "$LAST_RELEASE_RUNID" != "$EXPECTED_LAST_RELEASE_RUNID" ]; then
    echo "::error::Expected last-release-runid to be $EXPECTED_LAST_RELEASE_RUNID but got $LAST_RELEASE_RUNID"
    exit 1
fi
