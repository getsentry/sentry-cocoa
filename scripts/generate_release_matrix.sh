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
    pipelines          JSON array of {id, slice, variants} objects, one per
                       slice, each with the variants assembled from it
    sdk-list-array     JSON array of SDK names
    sdk-list-string    Comma-separated SDK names

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

# Slices and Variants only needed on PRs
#
# The Sentry slices build the SentryV10 scheme, whose framework is still named Sentry, so the
# variants below assemble them under the existing product names. SentryV10's xcconfig owns the
# dynamic Mach-O type, hence "inherit". The Xcode project has no V10 configuration without UIKit
# yet, so that variant still builds the V9 Sentry scheme.
BASE_SLICES_JSON='[
  {"name": "SentryV10", "macho-type": "inherit", "suffix": "-Dynamic", "id": "sentry-dynamic", "sdk-v10": true},
  {"name": "SentryV10", "macho-type": "staticlib", "id": "sentry-static", "sdk-v10": true},
  {"name": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic"}
]'
BASE_VARIANTS_JSON='[
  {"scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "excluded-archs": "arm64e"},
  {"scheme": "Sentry", "macho-type": "staticlib", "id": "sentry-static"},
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
    log_info "Pull request detected — using base slices/variants/SDKs only"
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS="$BASE_VARIANTS_JSON"
    SDK_LIST="$BASE_SDKS_JSON"
else
    log_info "Non-PR event — merging additional variants and SDKs"
    SLICES_COMBINATIONS="$BASE_SLICES_JSON"
    VARIANTS_COMBINATIONS=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_VARIANTS_JSON") <(echo "$ADDITIONAL_VARIANTS_JSON"))
    SDK_LIST=$(jq -c -s '.[0] + .[1]' <(echo "$BASE_SDKS_JSON") <(echo "$ADDITIONAL_SDKS_JSON"))
fi

# Group each slice with the variants assembled from it, so the release workflow can run one
# slices -> assemble pipeline per slice ID. A variant's assembly then waits only for its own
# slices instead of every slice in the matrix.
ORPHAN_VARIANTS=$(jq -r -n --argjson slices "$SLICES_COMBINATIONS" --argjson variants "$VARIANTS_COMBINATIONS" \
    '[$slices[].id] as $ids | [$variants[] | select(.id as $id | $ids | index($id) | not) | .id] | unique | join(",")')
if [ -n "$ORPHAN_VARIANTS" ]; then
    log_error "Variants without a matching slice ID: $ORPHAN_VARIANTS"
    exit 1
fi
PIPELINES_OUTPUT=$(jq -c -n --argjson slices "$SLICES_COMBINATIONS" --argjson variants "$VARIANTS_COMBINATIONS" \
    '[$slices[] | . as $slice | {id: $slice.id, slice: $slice, variants: [$variants[] | select(.id == $slice.id)]}]')
SDK_ARRAY_OUTPUT=$(echo "$SDK_LIST" | jq -c '.')
SDK_STRING_OUTPUT=$(echo "$SDK_LIST" | jq -r 'join(",")')

set_output "pipelines" "$PIPELINES_OUTPUT"
set_output "sdk-list-array" "$SDK_ARRAY_OUTPUT"
set_output "sdk-list-string" "$SDK_STRING_OUTPUT"

log_info "Generated matrix:"
log_info "  Pipelines:  $PIPELINES_OUTPUT"
log_info "  SDKs:       $SDK_STRING_OUTPUT"

end_group
