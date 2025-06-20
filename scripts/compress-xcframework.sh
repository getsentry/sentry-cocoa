#!/bin/bash

set -eoux pipefail

should_sign_arg="${1}"
framework="${2}" # examples: Sentry, Sentry-Dynamic, SentrySwiftUI, Sentry-WithoutUIKitOrAppKit

should_sign=false
[[ "$should_sign_arg" == "--sign" ]] && should_sign=true

sentry_certificate="Apple Distribution: GetSentry LLC (97JCY7859U)"

framework_path="$framework.xcframework"

if [[ "$should_sign" == true ]]; then
    echo "Signing $framework"
    # This is Sentry's certificate name, and should not change
    codesign --sign "$sentry_certificate" --timestamp --options runtime --deep --force "$framework_path"
fi

echo "Compressing $framework"
# use ditto here to avoid clobbering symlinks which exist in macOS frameworks
ditto -c -k -X --rsrc --keepParent "$framework_path" "$framework_path.zip"
