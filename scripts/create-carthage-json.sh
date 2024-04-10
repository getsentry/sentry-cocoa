#!/bin/bash
set -euo pipefail

echo "{ \"1.0\": \"file:///$(pwd)/Sentry.framework.zip?alt=file:///$(pwd)/Sentry.xcframework.zip\" }" > ./Samples/Carthage-Validation/Sentry.Carthage.json
echo "{ \"1.0\": \"file:///$(pwd)/SentrySwiftUI.framework.zip?alt=file:///$(pwd)/SentrySwiftUI.xcframework.zip\" }" > ./Samples/Carthage-Validation/SentrySwiftUI.Carthage.json
