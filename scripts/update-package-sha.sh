#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

if [ -z "$GITHUB_RUN_ID" ]; then
  log_error "GITHUB_RUN_ID is not set. Exiting script."
  exit 1
fi

PACKAGE_FILES=$(find . -maxdepth 1 -name "Package.swift" -o -name "Package@swift-*.swift" | sort)

if [ -z "$PACKAGE_FILES" ]; then
    log_error "No Package.swift or Package@swift-*.swift files found"
    exit 1
fi

# Each entry pairs the xcframework zip filename with the comment marker used
# in Package.swift (e.g. `checksum: "…" //Sentry-Static`). Specific markers
# (e.g. `-WithARM64e`) must come after their prefix markers so the broader
# substitution runs first and the specific one overrides it.
ZIPS_AND_MARKERS=(
    "Sentry.xcframework.zip|Sentry-Static"
    "Sentry-Dynamic.xcframework.zip|Sentry-Dynamic"
    "Sentry-Dynamic-WithARM64e.xcframework.zip|Sentry-Dynamic-WithARM64e"
    "Sentry-WithoutUIKitOrAppKit.xcframework.zip|Sentry-WithoutUIKitOrAppKit"
    "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip|Sentry-WithoutUIKitOrAppKit-WithARM64e"
    "SentryObjC-Static.xcframework.zip|SentryObjC-Static"
    "SentryObjC-Dynamic.xcframework.zip|SentryObjC-Dynamic"
)

os=$(uname)
# Craft pre-release command runs on an ubuntu machine
# and `sed` needs an extra argument for macOS.
if [ "$os" == "Linux" ]; then
    sed_inplace=( -i )
else
    sed_inplace=( -i "" )
fi

for package_file in $PACKAGE_FILES; do
    for entry in "${ZIPS_AND_MARKERS[@]}"; do
        zip="${entry%%|*}"
        marker="${entry##*|}"
        zip_path="XCFrameworkBuildPath/${zip}"
        if [ ! -f "$zip_path" ]; then
            echo "::warning::Skipping ${marker}: ${zip_path} not found"
            continue
        fi
        checksum=$(shasum -a 256 "$zip_path" | awk '{print $1}')
        sed "${sed_inplace[@]}" "s/checksum: \".*\" \/\/${marker}/checksum: \"${checksum}\" \/\/${marker}/" "$package_file"
    done
done

echo "$GITHUB_RUN_ID" > .github/last-release-runid
