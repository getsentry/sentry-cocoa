#!/bin/bash

set -oux pipefail

PLATFORM_SDK=${1:-all} # examples: all, ios, macosx, maccatalyst, tvos, watchos, visionos
DELIVERY_METHOD=${2:-all} # examples: all, cocoapods, spm, xcframework-static, xcframework-dynamic, carthage

FRAMEWORK_DIR="Integration/Frameworks"

# cocoapods doesn't use the prebuilt xcframeworks
if [ "$DELIVERY_METHOD" != "cocoapods" ]; then
  case "$DELIVERY_METHOD" in
    spm)
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "dynamic"
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "swiftui"
      XCFRAMEWORK_FILENAMES="Sentry-Dynamic.xcframework SentrySwiftUI.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry-Dynamic.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip"
    ;;
    xcframework-static)
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "static"
      XCFRAMEWORK_FILENAMES="Sentry.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry.xcframework.zip"
    ;;
    xcframework-dynamic)
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "dynamic"
      XCFRAMEWORK_FILENAMES="Sentry-Dynamic.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry-Dynamic.xcframework.zip"
    ;;
    carthage)
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "static"
      ./scripts/build-xcframework-local.sh "$PLATFORM_SDK" "swiftui"
      XCFRAMEWORK_FILENAMES="Sentry.xcframework SentrySwiftUI.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip"
    ;;
    all)
      ./scripts/build-xcframework-local.sh
      XCFRAMEWORK_FILENAMES="Sentry.xcframework SentrySwiftUI.xcframework Sentry-Dynamic.xcframework Sentry-WithoutUIKitOrAppKit.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip Sentry-Dynamic.xcframework.zip Sentry-WithoutUIKitOrAppKit.xcframework.zip"
    ;;
    *)
      echo "Invalid package delivery method"
      exit 1
    ;;
  esac
  
  "cp -Rf $XCFRAMEWORK_FILENAMES $FRAMEWORK_DIR"
  "cp -Rf $XCFRAMEWORK_ZIP_FILENAMES $FRAMEWORK_DIR"
fi

succeeded_tests=()
failed_tests=()

# Run the package integration tests for all platform and SDK variant combinations
# todo: add maccatalyst, it'll need to be special-cased for platform/destination combination
for platform in ios tvos watchos macos visionos; do
  for delivery_method in cocoapods spm xcframework-static xcframework-dynamic carthage; do
    if [ "$PLATFORM_SDK" == "all" ] || [ "$PLATFORM_SDK" == "$platform" ]; then
      if [ "$DELIVERY_METHOD" == "all" ] || [ "$DELIVERY_METHOD" == "$delivery_method" ]; then
        if [ "$DELIVERY_METHOD" == "coocapods" ] && [ "$PLATFORM_SDK" == "visionos" ]; then
          echo "visionos via cocoapods doesn't work due to the issue initially reported in https://github.com/getsentry/sentry-cocoa/issues/3809"
          continue
        fi
        if [ "$DELIVERY_METHOD" == "carthage" ] && [ "$PLATFORM_SDK" == "visionos" ]; then
          echo "carthage doesn't support visionos"
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

echo "Summary of the results:"
echo "Succeeded tests:"
for test in "${succeeded_tests[@]}"; do
  echo "  $test"
done
echo "Failed tests:"
for test in "${failed_tests[@]}"; do
  echo "  $test"
done
