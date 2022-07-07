#!/bin/bash

set -x

phase="$1"

# get the list of schemes with the following command
# xcodebuild -workspace Sentry.xcworkspace -list 2>/dev/null -quiet \
# | grep -v -e "Information about workspace" -e "Schemes:" -e "Sentry" \
# | awk '{print "\"" $1 " " $2 " " $3 "\""};' | sed 's/  //'

for scheme in "iOS-ObjectiveC" "iOS-ObjectiveCUITests" "iOS-Swift" "iOS-Swift-Benchmarking" "iOS-SwiftClip" "iOS-SwiftUI" "iOS-SwiftUI-UITests" "iOS-SwiftUITests" "iOS13-Swift" "iOS13-SwiftTests" "iOS15-SwiftUI" "iOS15-SwiftUITests" "iOS15-SwiftUIUITests" "macOS-Swift" "ProfileDataGeneratorUITest" "TrendingMovies" "tvOS-SBSwift" "tvOS-SBSwiftUITests" "tvOS-Swift" "tvOS-SwiftUITests" "watchOS-Swift" "watchOS-Swift WatchKit App" "watchOS-Swift WatchKit Extension"
do
    for config in "Debug" "Release"
    do
        xcodebuild -workspace Sentry.xcworkspace \
            -showBuildSettings \
            -scheme "$scheme" \
            -configuration $config \
                > xcodebuild_showBuildSettings_${phase}/${scheme}_${config}.txt \
                2>/dev/null
    done
done

# Output all build settings for all configs of the SentryTests target for all SDKs.
for sdk in "macosx" "iphoneos" "appletvos" "watchos"
do
    for config in "Debug" "Release" "Test" "TestCI"
    do
        for scheme in "Sentry" "SentryTests"
        do
            xcodebuild -workspace Sentry.xcworkspace \
                -showBuildSettings \
                -scheme $scheme \
                -configuration $config \
                -sdk $sdk \
                    > xcodebuild_showBuildSettings_${phase}/${scheme}_${config}_${sdk}.txt \
                    2>/dev/null
        done
    done
done

for project in "Framework" "XCFramework"
do
    for config in "Debug" "Release"
    do
        xcodebuild -project Samples/Carthage-Validation/$project/${project}.xcodeproj \
            -showBuildSettings \
            -scheme $project \
            -configuration $config \
                > xcodebuild_showBuildSettings_${phase}/Carthage-Validation_${project}_${config}.txt \
                2>/dev/null
    done
done
