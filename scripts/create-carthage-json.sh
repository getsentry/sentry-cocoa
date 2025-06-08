#!/bin/bash
set -euox pipefail

SPEC_PATH_FOLDER="${1:-./Samples/Carthage-Validation}"
XCFRAMEWORK_FOLDER="${2:-$(pwd)/Carthage}"

echo "{ \"1.0\": \"file://$XCFRAMEWORK_FOLDER/Sentry.framework.zip?alt=file://$XCFRAMEWORK_FOLDER/Sentry.xcframework.zip\" }" > "$SPEC_PATH_FOLDER/Sentry.Carthage.json"
echo "{ \"1.0\": \"file://$XCFRAMEWORK_FOLDER/SentrySwiftUI.framework.zip?alt=file://$XCFRAMEWORK_FOLDER/SentrySwiftUI.xcframework.zip\" }" > "$SPEC_PATH_FOLDER/SentrySwiftUI.Carthage.json"
