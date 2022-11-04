#!/bin/bash
set -eou pipefail

#echo "make build-xcframework"
#make build-xcframework  2>/dev/null
#
#echo "make build-xcframework-sample"
#make build-xcframework-sample 2>/dev/null

echo "./scripts/xcode-test.sh iOS latest"
./scripts/xcode-test.sh iOS latest local local 2>/dev/null

echo "./scripts/xcode-test.sh macOS latest"
./scripts/xcode-test.sh macOS latest local local 2>/dev/null

echo "./scripts/xcode-test.sh tvOS latest"
./scripts/xcode-test.sh tvOS latest local local 2>/dev/null

echo "fastlane ui_tests_ios_swift"
rbenv exec bundle exec fastlane ui_tests_ios_swift 2>/dev/null

echo "fastlane ui_tests_ios_objc"
rbenv exec bundle exec fastlane ui_tests_ios_objc 2>/dev/null

echo "fastlane ui_tests_tvos_swift"
rbenv exec bundle exec fastlane ui_tests_tvos_swift 2>/dev/null

echo "fastlane ui_tests_ios_swiftui"
rbenv exec bundle exec fastlane ui_tests_ios_swiftui 2>/dev/null
