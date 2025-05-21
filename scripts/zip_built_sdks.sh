#!/bin/bash

set -eou pipefail

args="${1:-}"

frameworks=( Sentry Sentry-Dynamic SentrySwiftUI Sentry-WithoutUIKitOrAppKit )

if [[ "$args" == "--sign" ]]; then
    for framework in "${frameworks[@]}"; do
        echo "Signing $framework"
        # This is Sentry's certificate name, and should not change
        codesign --sign "Apple Distribution: GetSentry LLC (97JCY7859U)" \
            --timestamp \
            --options runtime \
            --deep \
            --force \
            "Carthage/$framework.xcframework"
    done
fi

for framework in "${frameworks[@]}"; do
    echo "Zipping $framework"
    ditto -c -k -X --rsrc --keepParent "Carthage/$framework.xcframework" "Carthage/$framework.xcframework.zip"
done