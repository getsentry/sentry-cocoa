#!/bin/bash

set -x

phase="$1"

# get the list of schemes with the following command
# xcodebuild -project Sentry.xcodeproj -list 2>/dev/null -quiet \
# | grep -v -e "Information about workspace" -e "Schemes:" -e "Sentry" \
# | awk '{print "\"" $1 " " $2 " " $3 "\""};' | sed 's/  //'

for scheme in "iOS-ObjectiveC" "iOS-ObjectiveC-UITests" "iOS-Swift" "PerformanceBenchmarks" "iOS-Swift-Clip" "iOS-SwiftUI" "iOS-SwiftUI-UITests" "iOS-Swift-UITests" "iOS13-Swift" "iOS13-Swift-Tests" "iOS15-SwiftUI" "iOS15-SwiftUI-Tests" "iOS15-SwiftUI-UITests" "macOS-Swift" "ProfileDataGenerator" "TrendingMovies" "tvOS-SBSwift" "tvOS-SBSwiftUITests" "tvOS-Swift" "tvOS-Swift-UITests" "watchOS-Swift" "watchOS-Swift WatchKit App" "watchOS-Swift WatchKit Extension" "Sentry_iOS" "SentryTests_OiS" "Sentry_macOS" "SentryTests_macOS" "Sentry_tvOS" "SentryTests_tvOS" "Sentry_watchOS" "SentryTests_watchOS"
do
    for config in "Debug" "Release" "Test" "TestCI"
    do
        xcodebuild -project Sentry.xcodeproj \
            -showBuildSettings \
            -scheme "$scheme" \
            -configuration $config \
                > xcodebuild_showBuildSettings_${phase}/${scheme}_${config}.txt \
                2>/dev/null
    done
done
