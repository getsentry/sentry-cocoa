#!/bin/bash

set -ou pipefail

PLATFORM_SDK=${1:-all}
SDK_VARIANT=${2:-all}

# Build the xcframeworks locally
./scripts/build-xcframework-local.sh | tee build-xcframework.log

# Prepare the shared framework directory
FRAMEWORK_DIR="Integration/Frameworks"
rm -rf $FRAMEWORK_DIR
mkdir -p $FRAMEWORK_DIR
mv Sentry.xcframework Sentry-Dynamic.xcframework SentrySwiftUI.xcframework $FRAMEWORK_DIR
mv Carthage/Sentry.xcframework.zip Carthage/Sentry-Dynamic.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip $FRAMEWORK_DIR

# Initialize lists for succeeded and failed tests
succeeded_tests=()
failed_tests=()

# Run the package integration tests for all platform and SDK variant combinations
# todo: add maccatalyst
for platform in ios tvos watchos macos visionos; do
  # todo: add carthage
  for delivery_method in cocoapods spm xcframework-static xcframework-dynamic; do
    if [ "$PLATFORM_SDK" == "all" ] || [ "$PLATFORM_SDK" == "$platform" ]; then
      if [ "$SDK_VARIANT" == "all" ] || [ "$SDK_VARIANT" == "$delivery_method" ]; then
        if [ "$SDK_VARIANT" == "coocapods" ] && [ "$PLATFORM_SDK" == "visionos" ]; then
          # todo: visionos via cocoapods doesn't work due to the issue initially reported in https://github.com/getsentry/sentry-cocoa/issues/3809
          continue
        fi

        if ./scripts/package-integration-test.sh $platform $delivery_method; then
          echo "Succeeded integrating $platform via $delivery_method"
          succeeded_tests+=("$platform-$delivery_method")
        else
          failed_tests+=("$platform-$delivery_method")
        fi
      fi
    fi
  done
done

# Display the summary of results
echo "Summary of the results:"
echo "Succeeded tests:"
for test in "${succeeded_tests[@]}"; do
  echo "  $test"
done
echo "Failed tests:"
for test in "${failed_tests[@]}"; do
  echo "  $test"
done
