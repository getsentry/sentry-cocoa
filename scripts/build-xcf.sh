#!/bin/bash
# Builds XCFramework of all the possible destinations

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.." || exit 1
ARCHIVES_DIR="./Archives"
XCF_OUTPUT="./Sentry.xcframework"

mkdir -p "$ARCHIVES_DIR"
rm -rf "$XCF_OUTPUT"

archive() {
    xcodebuild archive -workspace Sentry.xcworkspace -scheme Sentry -destination "$1" -archivePath "$ARCHIVES_DIR/$2"
}

archive "generic/platform=iOS" "Sentry-ios"
archive "generic/platform=iOS Simulator" "Sentry-iossimulator"
archive "generic/platform=watchOS" "Sentry-watchos"
# This gets a warning due to matching both mac & mac-catalyst variants, but unclear how to be specific
archive "generic/platform=macOS" "Sentry-mac"
archive "generic/platform=macOS,variant=Mac Catalyst" "Sentry-maccatalyst"

# Combine them all into an XCFramework
XCARGS=()

# Thanks to shellcheck this got a little weirder, likely simpler if switched to zsh due to macOS bash's age
while IFS= read -r -d '' file
do
    XCARGS+=("-framework")
    XCARGS+=("$file")
done <   <(find "$ARCHIVES_DIR" -name 'Sentry.framework' -print0)

xcodebuild -create-xcframework "${XCARGS[@]}" -output "$XCF_OUTPUT"
