#!/bin/bash

# This script is used to generate the matrix combinations for the release workflow.
# Rewritten to use jq as much as possible for maintainability.

set -euo pipefail

# Slices and Variants only needed on PRs
BASE_SLICES_JSON='[
  {"name": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic"},
  {"name": "Sentry", "macho-type": "staticlib", "id": "sentry-static"},
  {"name": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui"},
  {"name": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic"}
]'
BASE_VARIANTS_JSON='[
  {"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "excluded-archs": "arm64e"},
  {"scheme": "Sentry", "macho-type": "staticlib", "id": "sentry-static"},
  {"scheme": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui"},
  {"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "excluded-archs": "arm64e"}
]'
BASE_SDKS_JSON='[
  "iphoneos",
  "iphonesimulator",
  "macosx",
  "maccatalyst",
  "appletvos",
  "watchos",
  "xros"
]'

# Slices and Variants only needed on main or release
ADDITIONAL_VARIANTS_JSON='[
  {"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "override-name": "Sentry-Dynamic-WithARM64e"},
  {"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "override-name": "Sentry-WithoutUIKitOrAppKit-WithARM64e"}
]'
ADDITIONAL_SDKS_JSON='[
  "appletvsimulator",
  "watchsimulator",
  "xrsimulator"
]'

if [ "$EVENT_NAME" = "pull_request" ]; then
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS="$BASE_VARIANTS_JSON"
    SDK_LIST="$BASE_SDKS_JSON"
else
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_VARIANTS_JSON") <(echo "$ADDITIONAL_VARIANTS_JSON"))
    SDK_LIST=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_SDKS_JSON") <(echo "$ADDITIONAL_SDKS_JSON"))
fi

{
  echo "slices=$(echo "$SLICES_COMBINATIONS" | jq -c '.')"
  echo "variants=$(echo "$VARIANTS_COMBINATIONS" | jq -c '.')"
  echo "sdk-list-array=$(echo "$SDK_LIST" | jq -c '.')"
  echo "sdk-list-string=$(echo "$SDK_LIST" | jq -r 'join(",")')"
}  >> "$GITHUB_OUTPUT"
