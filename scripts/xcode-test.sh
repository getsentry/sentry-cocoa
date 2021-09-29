#!/bin/bash
set -euo pipefail

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

PLATFORM="${1}"
DESTINATION=""

case $PLATFORM in

    "macOS")
        DESTINATION="platform=macOS"
        ;;

    "Catalyst")
        DESTINATION="platform=macOS,variant=Mac Catalyst"
        ;;

    "iOS")
        DESTINATION="platform=iOS Simulator,OS=latest,name=iPhone 11"
        ;;

    "tvOS")
        DESTINATION="platform=tvOS Simulator,OS=latest,name=Apple TV 4K"
        ;;
    
    *)
        echo "Xcode Test: Can't find destination for platform '$PLATFORM'"; 
        exit 1;
        ;;
esac

xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Release GCC_GENERATE_TEST_COVERAGE_FILES=YES GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES -destination "$DESTINATION" test | xcpretty -t && exit ${PIPESTATUS[0]}
