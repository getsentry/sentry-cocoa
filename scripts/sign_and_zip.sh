#!/bin/bash

set -eou pipefail

args="${1:-}"

if [ -z "$args" ]; then
    echo "Usage: $0 <path-to-xcframework>"
    exit 1
fi

codesign --sign "Apple Distribution: GetSentry LLC (97JCY7859U)" \
         --timestamp \
         --options runtime \
         --deep \
         --force \
         "$args"

ditto -c -k -X --rsrc --keepParent "$args" "$args.zip"
