#!/bin/bash
set -eoux pipefail

make build-xcframework 2>&1 > build-xcframework_stderr.log
make build-xcframework-sample 2>&1 > build-xcframework-sample_stderr.log
./scripts/xcode-test.sh iOS latest local local 2>&1 > ios_test_stderr.log
./scripts/xcode-test.sh macOS latest local local 2>&1 > macos_test_stderr.log
./scripts/xcode-test.sh tvOS latest local local 2>&1 > tvos_test_stderr.log
rbenv exec bundle exec fastlane ui_tests_ios_swift 2>&1 > ios-swift_uitest_stderr.log
rbenv exec bundle exec fastlane ui_tests_ios_objc 2>&1 > ios-objc.log
rbenv exec bundle exec fastlane ui_tests_tvos_swift 2>&1 > tvos-swift_uitest_stderr.log
rbenv exec bundle exec fastlane ui_tests_ios_swiftui 2>&1 > ios-swiftui_uitest_stderr.log
