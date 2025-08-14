#!/bin/bash

# This script is used to generate the matrix combinations for the release workflow.

set -euo pipefail

# Slices and Variants only needed on PRs
BASE_SLICES=(
    '{"name": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic"}'
    '{"name": "Sentry", "macho-type": "staticlib", "id": "sentry-static"}'
    '{"name": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui"}'
)
BASE_VARIANTS=(
    '{"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "excluded-archs": "arm64e"}'
    '{"scheme": "Sentry", "macho-type": "staticlib", "id": "sentry-static"}'
    '{"scheme": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui"}'
)
BASE_SDKS=(
    '"iphoneos"'
    '"iphonesimulator"'
    '"macosx"'
)

# Slices and Variants only needed on main or release
ADDITIONAL_SLICES=(
    '{"name": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic"}'
)
ADDITIONAL_VARIANTS=(
    '{"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "override-name": "Sentry-Dynamic-WithARM64e"}'
    '{"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "excluded-archs": "arm64e"}'
    '{"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "override-name": "Sentry-WithoutUIKitOrAppKit-WithARM64e"}'
)
ADDITIONAL_SDKS=(
    '"maccatalyst"'
    '"appletvos"'
    '"appletvsimulator"'
    '"watchos"'
    '"watchsimulator"'
    '"xros"'
    '"xrsimulator"'
)

build_json_array() {
    local array_name=$1
    local result="["
    local first=true
    
    # Get the array elements using indirect expansion
    local array_values
    eval "array_values=(\"\${${array_name}[@]}\")"
    
    for item in "${array_values[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            result+=","
        fi
        result+="$item"
    done
    
    result+="]"
    echo "$result"
}

if [ "$EVENT_NAME" = "pull_request" ]; then
    SLICES_COMBINATIONS=$(build_json_array BASE_SLICES)
    VARIANTS_COMBINATIONS=$(build_json_array BASE_VARIANTS)
    SDK_LIST=$(build_json_array BASE_SDKS)
else
    # shellcheck disable=SC2034
    ALL_SLICES=("${BASE_SLICES[@]}" "${ADDITIONAL_SLICES[@]}")
    # shellcheck disable=SC2034
    ALL_VARIANTS=("${BASE_VARIANTS[@]}" "${ADDITIONAL_VARIANTS[@]}")
    # shellcheck disable=SC2034
    ALL_SDKS=("${BASE_SDKS[@]}" "${ADDITIONAL_SDKS[@]}")
    
    SLICES_COMBINATIONS=$(build_json_array ALL_SLICES)
    VARIANTS_COMBINATIONS=$(build_json_array ALL_VARIANTS)
    SDK_LIST=$(build_json_array ALL_SDKS)
fi

{
  echo "slices=$SLICES_COMBINATIONS"
  echo "variants=$VARIANTS_COMBINATIONS"
  echo "sdk-list-array=$SDK_LIST"
  echo "sdk-list-string=$(echo "$SDK_LIST" | jq -r 'join(",")')"
} >> "$GITHUB_OUTPUT"
