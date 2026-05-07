#!/bin/bash

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Generate matrix combinations for the release workflow.

Reads EVENT_NAME from the environment to decide which slices, variants,
and SDKs to include. Pull requests get the base set; other events
(push to main, release) additionally include arm64e and simulator SDKs.

ENVIRONMENT:
    EVENT_NAME    GitHub Actions event name (e.g., pull_request, push)

OUTPUTS (via GITHUB_OUTPUT):
    slices             JSON array of slice definitions
    variants           JSON array of variant definitions
    sdk-list-array     JSON array of SDK names
    sdk-list-string    Comma-separated SDK names

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

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

begin_group "Compute matrix for EVENT_NAME=${EVENT_NAME:-unset}"

if [ "${EVENT_NAME:-}" = "pull_request" ]; then
    echo "Pull request detected — using base slices/variants/SDKs only"
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS="$BASE_VARIANTS_JSON"
    SDK_LIST="$BASE_SDKS_JSON"
else
    echo "Non-PR event — merging additional variants and SDKs"
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_VARIANTS_JSON") <(echo "$ADDITIONAL_VARIANTS_JSON"))
    SDK_LIST=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_SDKS_JSON") <(echo "$ADDITIONAL_SDKS_JSON"))
fi

SLICES_OUTPUT=$(echo "$SLICES_COMBINATIONS" | jq -c '.')
VARIANTS_OUTPUT=$(echo "$VARIANTS_COMBINATIONS" | jq -c '.')
SDK_ARRAY_OUTPUT=$(echo "$SDK_LIST" | jq -c '.')
SDK_STRING_OUTPUT=$(echo "$SDK_LIST" | jq -r 'join(",")')

set_output "slices" "$SLICES_OUTPUT"
set_output "variants" "$VARIANTS_OUTPUT"
set_output "sdk-list-array" "$SDK_ARRAY_OUTPUT"
set_output "sdk-list-string" "$SDK_STRING_OUTPUT"

echo "Generated matrix:"
echo "  Slices:     $SLICES_OUTPUT"
echo "  Variants:   $VARIANTS_OUTPUT"
echo "  SDKs:       $SDK_STRING_OUTPUT"

end_group
