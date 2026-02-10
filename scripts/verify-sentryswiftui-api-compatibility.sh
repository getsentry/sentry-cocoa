#!/usr/bin/env bash
#
# Verifies that all SentrySwiftUI exported types remain accessible when importing SentrySwiftUI.
# This replaces the sdk_api_sentryswiftui.json diff for API stability, since SentrySwiftUI now
# uses @_exported import Sentry and swift-api-digester does not traverse re-exports.
#
# The XCFramework-Validation sample imports SentrySwiftUI and uses SentryTracedView, sentryTrace(),
# and other types. If it builds successfully, the API is preserved.
#
# Prerequisites:
# - Sentry-Dynamic.xcframework and SentrySwiftUI.xcframework must exist in the repo root
#   (built by update-api.sh)

set -euo pipefail

# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

begin_group "Verify SentrySwiftUI API Compatibility"
log_notice "Preparing XCFrameworkBuildPath for sample build"

# The XCFramework-Validation sample expects Sentry.xcframework and SentrySwiftUI.xcframework
# in XCFrameworkBuildPath. update-api.sh produces Sentry-Dynamic.xcframework and
# SentrySwiftUI.xcframework in the repo root. Both provide the Sentry module.
mkdir -p XCFrameworkBuildPath
cp -R Sentry-Dynamic.xcframework XCFrameworkBuildPath/Sentry.xcframework
cp -R SentrySwiftUI.xcframework XCFrameworkBuildPath/SentrySwiftUI.xcframework

log_notice "Removing expectedSignature for CI build"
sed -i '' 's/expectedSignature = "[^"]*"; //g' Samples/XCFramework-Validation/XCFramework.xcodeproj/project.pbxproj 2>/dev/null || \
  sed -i 's/expectedSignature = "[^"]*"; //g' Samples/XCFramework-Validation/XCFramework.xcodeproj/project.pbxproj

log_notice "Building XCFramework-Validation sample (imports SentrySwiftUI, uses SentryTracedView, sentryTrace)"
xcodebuild -project "Samples/XCFramework-Validation/XCFramework.xcodeproj" \
  -configuration Release \
  CODE_SIGNING_ALLOWED="NO" \
  build

log_notice "SentrySwiftUI API compatibility verified successfully"
end_group
