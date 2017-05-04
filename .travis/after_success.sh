#!/bin/sh
if [ "$LANE" = "test" ];
then
    xcodebuild -project Sentry.xcodeproj -scheme SentryTests build test -sdk iphonesimulator GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES
    bash <(curl -s https://codecov.io/bash) -J '^Swift$'
elif [ "$LANE" = "do_cocoapods" ];
then
    xcodebuild -project Sentry.xcodeproj -scheme SentrySwiftTests build test -sdk iphonesimulator GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES
    bash <(curl -s https://codecov.io/bash) -J '^SentrySwift$'
fi
