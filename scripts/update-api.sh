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

export SDK_V10=0

# Build both frameworks at once, as they depend on each other
begin_group "Build Sentry-Dynamic XCFramework"
log_info "Building Sentry-Dynamic slice"
"$SCRIPT_DIR/build-xcframework-slice.sh" --sdk iphoneos --scheme Sentry --suffix '-Dynamic' --mach-o-type mh_dylib

log_info "Assembling Sentry-Dynamic xcframework"
"$SCRIPT_DIR/assemble-xcframework.sh" --scheme Sentry --suffix '-Dynamic' --sdks iphoneos \
    --archive-template "$(pwd)/XCFrameworkBuildPath/archive/Sentry-Dynamic/SDK_NAME.xcarchive"
end_group

begin_group "Build SentrySwiftUI XCFramework"
log_info "Building SentrySwiftUI slice"
"$SCRIPT_DIR/build-xcframework-slice.sh" --sdk iphoneos --scheme SentrySwiftUI --mach-o-type mh_dylib

log_info "Assembling SentrySwiftUI xcframework"
"$SCRIPT_DIR/assemble-xcframework.sh" --scheme SentrySwiftUI --sdks iphoneos \
    --archive-template "$(pwd)/XCFrameworkBuildPath/archive/SentrySwiftUI/SDK_NAME.xcarchive"
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

# V10 API extraction uses the KSCrash-backed target that V10 ships.
export SDK_V10=1

begin_group "Build Sentry V10 XCFramework"
"$SCRIPT_DIR/build-xcframework-v10.sh" \
    --suffix "-Dynamic" \
    --sdks iphoneos
end_group

begin_group "Extract V10 Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module Sentry \
    --output sdk_api_v10.json \
    --framework-path "./SentryV10-Dynamic.xcframework/ios-arm64_arm64e"
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

# SwiftPM snapshots use separate filenames to preserve the framework snapshots.
export SDK_V10=0
SPM_BUILD_DIR="$(pwd)/DerivedData/API-SPM"
SPM_ARCHIVE="$SPM_BUILD_DIR/archive/SentrySPM/iphoneos.xcarchive"

begin_group "Build Sentry SwiftPM XCFramework"
"$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
    --sdk iphoneos --scheme SentrySPM --architecture-target SentrySwift \
    --configuration Release --output-dir "$SPM_BUILD_DIR"
"$SCRIPT_DIR/build-dynamic-framework-sentryobjc.sh" \
    --sdk iphoneos --framework-name SentrySwift --swift-archive "$SPM_ARCHIVE" \
    --static-lib "$SPM_BUILD_DIR/lib/SentrySPM/iphoneos/libSentrySPM-Debug.a" \
    --headers "$(pwd)/Sources/Sentry/Public" --output-dir "$SPM_BUILD_DIR"
"$SCRIPT_DIR/assemble-xcframework.sh" \
    --sdks iphoneos \
    --framework-template "$SPM_BUILD_DIR/framework/SentrySwift/SDK_NAME/SentrySwift.framework" \
    --output "$(pwd)/Sentry-SPM.xcframework"
end_group

begin_group "Extract SwiftPM Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module SentrySwift \
    --output sdk_api_spm.json \
    --framework-path "$(pwd)/Sentry-SPM.xcframework/ios-arm64"
end_group

# TODO: Extract SentrySwiftUI against the source-built SDK.
# Its current package target re-exports the prebuilt Sentry binary.
# The framework snapshot is still generated above.
log_info "Skipping SentrySwiftUI SwiftPM: no source-backed package target is available yet."

begin_group "Extract SentryObjC SwiftPM Public API"
"$SCRIPT_DIR/extract-objc-api.sh" \
    --output sdk_api_objc_spm.json
end_group

begin_group "Reuse SentryObjCCompat SwiftPM Public API"
# The original compatibility extraction already builds the same SwiftPM wrapper product.
cp sdk_api_objccompat.json sdk_api_objccompat_spm.json
end_group

begin_group "Diff SentryObjC vs SentryObjCCompat (SwiftPM)"
"$SCRIPT_DIR/generate-objc-compat-api-diff.sh" \
    --headers sdk_api_objc_spm.json \
    --compat sdk_api_objccompat_spm.json \
    --output sdk_api_objc_spm.diff.json
end_group

export SDK_V10=1
SPM_BUILD_DIR="$(pwd)/DerivedData/API-SPM-V10"
SPM_ARCHIVE="$SPM_BUILD_DIR/archive/Sentry/iphoneos.xcarchive"

begin_group "Build Sentry V10 SwiftPM XCFramework"
# V10 still compiles SentrySwift on this base; update the module name when #9459 lands.
"$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
    --sdk iphoneos --scheme Sentry --architecture-target SentrySwift \
    --configuration ReleaseV10 --output-dir "$SPM_BUILD_DIR"
"$SCRIPT_DIR/build-dynamic-framework-sentryobjc.sh" \
    --sdk iphoneos --framework-name SentrySwift --swift-archive "$SPM_ARCHIVE" \
    --static-lib "$SPM_BUILD_DIR/lib/Sentry/iphoneos/libSentry-Debug.a" \
    --headers "$(pwd)/Sources/Sentry/Public" --output-dir "$SPM_BUILD_DIR"
"$SCRIPT_DIR/assemble-xcframework.sh" \
    --sdks iphoneos \
    --framework-template "$SPM_BUILD_DIR/framework/SentrySwift/SDK_NAME/SentrySwift.framework" \
    --output "$(pwd)/SentryV10-SPM.xcframework"
end_group

begin_group "Extract V10 SwiftPM Public API"
"$SCRIPT_DIR/extract-swift-api.sh" \
    --module SentrySwift \
    --output sdk_api_v10_spm.json \
    --framework-path "$(pwd)/SentryV10-SPM.xcframework/ios-arm64"
end_group

begin_group "Extract SentryObjC V10 SwiftPM Public API"
"$SCRIPT_DIR/extract-objc-api.sh" \
    --output sdk_api_objc_v10_spm.json \
    --define SDK_V10=1
end_group

begin_group "Reuse SentryObjCCompat V10 SwiftPM Public API"
cp sdk_api_objccompat_v10.json sdk_api_objccompat_v10_spm.json
end_group

begin_group "Diff SentryObjC vs SentryObjCCompat (V10 SwiftPM)"
"$SCRIPT_DIR/generate-objc-compat-api-diff.sh" \
    --headers sdk_api_objc_v10_spm.json \
    --compat sdk_api_objccompat_v10_spm.json \
    --output sdk_api_objc_v10_spm.diff.json
end_group
