#!/bin/bash
set -euo pipefail

echo "{ \"1.0\": \"file:///$(pwd)/Carthage/Sentry.framework.zip?alt=file:///$(pwd)/Carthage/Sentry.xcframework.zip\" }" > ./Samples/Carthage-Validation/Sentry.Carthage.json
echo "{ \"1.0\": \"file:///$(pwd)/Carthage/SentrySwiftUI.framework.zip?alt=file:///$(pwd)/Carthage/SentrySwiftUI.xcframework.zip\" }" > ./Samples/Carthage-Validation/SentrySwiftUI.Carthage.json
