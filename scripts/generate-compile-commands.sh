#!/usr/bin/env bash

# Generates compile_commands.json from Xcode build output.
# Required for clang-tidy to parse Objective-C files with correct include paths.
#
# Uses xcpretty's json-compilation-database reporter to extract compiler
# invocations from xcodebuild output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/compile_commands.json"

cd "$REPO_ROOT"

echo "Generating compile_commands.json (this runs a full build)..."

# Build for iOS Simulator to capture all ObjC compilation commands
# Use Sentry scheme which includes Sources and Tests
# Destination matches CI runners (macos-15 has iOS 18.5)
set -o pipefail
xcodebuild \
    -workspace Sentry.xcworkspace \
    -scheme Sentry \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee /tmp/xcodebuild-output.log | bundle exec xcpretty -r json-compilation-database -o "$OUTPUT_FILE"

# xcpretty might exit non-zero even when it produced output; check if we got a valid file
if [[ -f "$OUTPUT_FILE" ]]; then
    # Validate it's valid JSON
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo "Generated $OUTPUT_FILE"

        # Count entries
        COUNT=$(jq '. | length' "$OUTPUT_FILE")
        echo "Contains $COUNT compilation units"
    else
        echo "Warning: $OUTPUT_FILE was generated but is not valid JSON"
        rm -f "$OUTPUT_FILE"
        exit 1
    fi
else
    echo "Error: Failed to generate compile_commands.json"
    echo "Check /tmp/xcodebuild-output.log for build details"
    exit 1
fi
