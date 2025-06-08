#!/bin/bash

set -ou pipefail

PLATFORM_SDK=${1:-allPlatforms} # examples: allPlatforms, ios, macosx, maccatalyst, tvos, watchos, visionos
PACKAGE_TYPE=${2:-allPackageTypes} # examples: allPackageTypes, cocoapods, spm, xcframework-static, xcframework-dynamic, carthage

echo "--------------------------------"
echo "Integration testing ${PLATFORM_SDK} via ${PACKAGE_TYPE}."
echo "--------------------------------"

FRAMEWORK_DIR="Integration/Frameworks"
mkdir -p "$FRAMEWORK_DIR"

# cocoapods doesn't use the prebuilt xcframeworks
if [ "$PACKAGE_TYPE" != "cocoapods" ]; then
  case "$PACKAGE_TYPE" in
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
    allPackageTypes)
      ./scripts/build-xcframework-local.sh
      XCFRAMEWORK_FILENAMES="Sentry.xcframework SentrySwiftUI.xcframework Sentry-Dynamic.xcframework Sentry-WithoutUIKitOrAppKit.xcframework"
      XCFRAMEWORK_ZIP_FILENAMES="Carthage/Sentry.xcframework.zip Carthage/SentrySwiftUI.xcframework.zip Sentry-Dynamic.xcframework.zip Sentry-WithoutUIKitOrAppKit.xcframework.zip"
    ;;
    *)
      echo "Invalid package delivery method"
      exit 1
    ;;
  esac
  
  eval "cp -Rf $XCFRAMEWORK_FILENAMES $FRAMEWORK_DIR"
  eval "cp -f $XCFRAMEWORK_ZIP_FILENAMES $FRAMEWORK_DIR"
fi

succeeded_tests=()
failed_tests=()

# Run the package integration tests for all platform and SDK variant combinations
# todo: add maccatalyst, it'll need to be special-cased for platform/destination combination
for platform in ios tvos watchos macos visionos; do
  for package_type in cocoapods spm xcframework-static xcframework-dynamic carthage; do
    if [ "$PLATFORM_SDK" == "allPlatforms" ] || [ "$PLATFORM_SDK" == "$platform" ]; then
      if [ "$PACKAGE_TYPE" == "allPackageTypes" ] || [ "$PACKAGE_TYPE" == "$package_type" ]; then

        if [ "$package_type" == "cocoapods" ] && [ "$platform" == "visionos" ]; then
          echo "visionos via cocoapods doesn't work due to the issue initially reported in https://github.com/getsentry/sentry-cocoa/issues/3809"
          continue
        fi
        if [ "$package_type" == "carthage" ] && [ "$platform" == "visionos" ]; then
          echo "carthage doesn't support visionos"
          continue
        fi

        if ./scripts/package-integration-test.sh $platform $package_type; then
          echo "Succeeded integrating $platform via $package_type"
          succeeded_tests+=("$platform-$package_type")
        else
          failed_tests+=("$platform-$package_type")
        fi
      fi
    fi
  done
done

echo "Succeeded tests:"
for test in "${succeeded_tests[@]}"; do
  echo "  $test"
done
echo "Failed tests:"
for test in "${failed_tests[@]}"; do
  echo "  $test"
done
