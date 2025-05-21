#!/bin/bash

set -eou pipefail

args="${1:-}"

frameworks=( Sentry Sentry-Dynamic SentrySwiftUI Sentry-WithoutUIKitOrAppKit )

should_sign=false
[[ "$args" == "--sign" ]] && should_sign=true

sentry_certificate="Apple Distribution: GetSentry LLC (97JCY7859U)"

for framework in "${frameworks[@]}"; do
    framework_path="Carthage/$framework.xcframework"

    if [[ "$should_sign" == true ]]; then
        echo "Signing $framework"
        # This is Sentry's certificate name, and should not change
        codesign --sign "$sentry_certificate" --timestamp --options runtime --deep --force "$framework_path"
    fi

    echo "Zipping $framework"
    ditto -c -k -X --rsrc --keepParent "$framework_path" "$framework_path.zip"
done