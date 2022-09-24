#!/bin/bash

# This script helps run SentryDeviceTests on all possible devices.

set -uox pipefail

CONFIGURATION="$1"

# This can be one of the following options:
# - "simulators": run against all mac and simulator targets
# - "iphone": run on a real iPhone
# - "ipad": run on a real iPad
# - "tv": run on a real TV
# - "watch": run on a real Watch
DEVICE_TYPE="$2"

if [[ $DEVICE_TYPE == "simulators" ]]; then
    for DESTINATION in \
    'platform=iOS Simulator,OS=16.0,name=iPhone SE (3rd generation)' \
    'platform=iOS Simulator,OS=16.0,name=iPad mini (6th generation)' \
    'platform=tvOS Simulator,OS=16.0,name=Apple TV 4K (2nd generation)' \
    'platform=macOS,arch=arm64' \
    'platform=macOS,arch=x86_64' \
    'platform=macOS,arch=arm64,variant=Mac Catalyst' \
    'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
    ; do
        echo "destination: '$DESTINATION'"
        env NSUnbufferedIO=YES \
            xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration $CONFIGURATION \
                -destination "$DESTINATION" \
                -only-testing:"SentryTests/SentryDeviceTests" \
                test \
                    | tee "raw-test-log-$DEVICE_TYPE-devices.log" \
                    | rbenv exec bundle exec xcpretty -t
    done
elif [[ $DEVICE_TYPE == "iphone" ]]; then

elif [[ $DEVICE_TYPE == "ipad" ]]; then

elif [[ $DEVICE_TYPE == "tv" ]]; then

elif [[ $DEVICE_TYPE == "watch" ]]; then

else
    echo "Invalid DEVICE_TYPE. Choose from 'simulators', 'iphone', 'ipad', 'tv' or 'watch'."
fi
