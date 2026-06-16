#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

begin_group "Check Xcode Version"
# Check if Xcode 16 is selected
# Read full output first to avoid broken pipe (SIGPIPE) error with pipefail
XCODE_VERSION_OUTPUT=$(xcodebuild -version)
XCODE_VERSION=$(echo "$XCODE_VERSION_OUTPUT" | awk 'NR==1 {print $2}')
XCODE_MAJOR_VERSION=$(echo "$XCODE_VERSION" | cut -d. -f1)

if [[ "$XCODE_MAJOR_VERSION" != "16" ]]; then
    # Try to find an Xcode 16 installation
    XCODE_16_PATH=$(find /Applications -maxdepth 1 -type d -name "Xcode-16*" 2>/dev/null | head -n 1)

    if [[ -n "$XCODE_16_PATH" ]]; then
        log_info "Xcode $XCODE_VERSION is currently selected, but found Xcode 16 at $XCODE_16_PATH"
        log_info "Using Xcode 16 for this script execution..."
        export DEVELOPER_DIR="$XCODE_16_PATH/Contents/Developer"

        # Verify the Xcode 16 installation works
        # Read full output first to avoid broken pipe (SIGPIPE) error with pipefail
        XCODE_16_VERSION_OUTPUT=$(xcodebuild -version)
        XCODE_16_VERSION=$(echo "$XCODE_16_VERSION_OUTPUT" | awk 'NR==1 {print $2}')
        XCODE_16_MAJOR_VERSION=$(echo "$XCODE_16_VERSION" | cut -d. -f1)

        if [[ "$XCODE_16_MAJOR_VERSION" != "16" ]]; then
            log_error "Found Xcode installation at $XCODE_16_PATH but it's version $XCODE_16_VERSION, not 16"
            end_group
            exit 1
        fi

        log_info "Successfully using Xcode 16 ($XCODE_16_VERSION)"
    else
        log_error "Xcode 16 is required for running the update-api.sh script, because Xcode 26 doesn't include the ObjC public API, but Xcode $XCODE_VERSION is currently selected."
        log_error "Please select Xcode 16 using 'sudo xcode-select' or 'xcodes select 16.x'"
        log_error "Alternatively, install Xcode 16 as '/Applications/Xcode-16*.app'"
        end_group
        exit 1
    fi
fi
end_group

# Build both frameworks at once, as they depend on each other
begin_group "Build Sentry-Dynamic XCFramework"
log_info "Building Sentry-Dynamic slice"
"$SCRIPT_DIR/build-xcframework-slice.sh" "iphoneos" "Sentry" "-Dynamic" "mh_dylib"

log_info "Assembling Sentry-Dynamic xcframework"
"$SCRIPT_DIR/assemble-xcframework.sh" "Sentry" "-Dynamic" "" "iphoneos" "$(pwd)/XCFrameworkBuildPath/archive/Sentry-Dynamic/SDK_NAME.xcarchive"
end_group

begin_group "Build SentrySwiftUI XCFramework"
log_info "Building SentrySwiftUI slice"
"$SCRIPT_DIR/build-xcframework-slice.sh" "iphoneos" "SentrySwiftUI" "" "mh_dylib"

log_info "Assembling SentrySwiftUI xcframework"
"$SCRIPT_DIR/assemble-xcframework.sh" "SentrySwiftUI" "" "" "iphoneos" "$(pwd)/XCFrameworkBuildPath/archive/SentrySwiftUI/SDK_NAME.xcarchive"
end_group

begin_group "Extract Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module Sentry \
    --output sdk_api.json \
    --framework-path "./Sentry-Dynamic.xcframework/ios-arm64_arm64e"
end_group

begin_group "Extract SentrySwiftUI Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module SentrySwiftUI \
    --output sdk_api_sentryswiftui.json \
    --framework-path "$(pwd)/SentrySwiftUI.xcframework/ios-arm64_arm64e" \
    --framework-path "$(pwd)/Sentry-Dynamic.xcframework/ios-arm64_arm64e"
end_group

begin_group "Extract SentryObjC Public API"
"$SCRIPT_DIR/extract-objc-api.sh" \
    --output sdk_api_objc.json
end_group

begin_group "Extract SentryObjCCompat Public API"
"$SCRIPT_DIR/extract-objc-compat-api.sh" \
    --output sdk_api_objccompat.json
end_group

begin_group "Diff SentryObjC vs SentryObjCCompat"
"$SCRIPT_DIR/generate-objc-compat-api-diff.sh" \
    --headers sdk_api_objc.json \
    --compat sdk_api_objccompat.json \
    --output sdk_api_objc.diff.json
end_group

# V10 API extraction — rebuilds with ReleaseV10 configuration (SDK_V10 flag)
# to track the V10 API surface separately from the base SDK.
# The V10 configuration uses the same product/module name (Sentry) but
# compiles with SDK_V10=1, so #if SDK_V10 branches are included.

begin_group "Build Sentry-Dynamic V10 XCFramework"
log_info "Building Sentry-Dynamic V10 slice"
"$SCRIPT_DIR/build-xcframework-slice.sh" "iphoneos" "Sentry" "-Dynamic-V10" "mh_dylib" "V10"

log_info "Assembling Sentry-Dynamic V10 xcframework"
# configuration_suffix is empty here because the product name inside the
# archive is still "Sentry.framework" (xcconfig controls PRODUCT_NAME).
"$SCRIPT_DIR/assemble-xcframework.sh" "Sentry" "-Dynamic-V10" "" "iphoneos" "$(pwd)/XCFrameworkBuildPath/archive/Sentry-Dynamic-V10/SDK_NAME.xcarchive"
end_group

begin_group "Extract V10 Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module Sentry \
    --output sdk_api_v10.json \
    --framework-path "./Sentry-Dynamic-V10.xcframework/ios-arm64_arm64e"
end_group

begin_group "Extract SentryObjC V10 Public API"
"$SCRIPT_DIR/extract-objc-api.sh" \
    --output sdk_api_objc_v10.json \
    --define SDK_V10=1
end_group

begin_group "Extract SentryObjCCompat V10 Public API"
"$SCRIPT_DIR/extract-objc-compat-api.sh" \
    --output sdk_api_objccompat_v10.json \
    --configuration ReleaseV10
end_group

begin_group "Diff SentryObjC vs SentryObjCCompat (V10)"
"$SCRIPT_DIR/generate-objc-compat-api-diff.sh" \
    --headers sdk_api_objc_v10.json \
    --compat sdk_api_objccompat_v10.json \
    --output sdk_api_objc_v10.diff.json
end_group
