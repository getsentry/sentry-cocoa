#!/bin/bash

# This script is used to generate the matrix combinations for the release workflow.

if [ "$EVENT_NAME" = "pull_request" ]; then
  SLICES_COMBINATIONS='
    [
      { "name": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic" },
      { "name": "Sentry", "macho-type": "staticlib", "id": "sentry-static" }
    ]
  '
  VARIANTS_COMBINATIONS='
    [
      { "scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "override-name": "Sentry-Dynamic-WithARM64e" },
      { "scheme": "Sentry", "macho-type": "staticlib", "id": "sentry-static" }
    ]
  '
else
  SLICES_COMBINATIONS='
    [
      { "name": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic" },
      { "name": "Sentry", "macho-type": "staticlib", "id": "sentry-static" },
      { "name": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui" },
      { "name": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic" }
    ]
  '
  VARIANTS_COMBINATIONS='
    [
      { "scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "excluded-archs": "arm64e" },
      { "scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-Dynamic", "id": "sentry-dynamic", "override-name": "Sentry-Dynamic-WithARM64e" },
      { "scheme": "Sentry", "macho-type": "staticlib", "id": "sentry-static" },
      { "scheme": "SentrySwiftUI", "macho-type": "mh_dylib", "id": "sentry-swiftui" },
      { "scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "excluded-archs": "arm64e" },
      { "scheme": "Sentry", "macho-type": "mh_dylib", "suffix": "-WithoutUIKitOrAppKit", "configuration-suffix": "WithoutUIKit", "id": "sentry-withoutuikit-dynamic", "override-name": "Sentry-WithoutUIKitOrAppKit-WithARM64e" }
    ]
  '
fi

echo "SLICES_COMBINATIONS=$SLICES_COMBINATIONS"

echo "slices=$( echo "$SLICES_COMBINATIONS" | jq -c . )" >> "$GITHUB_OUTPUT"
echo "variants=$( echo "$VARIANTS_COMBINATIONS" | jq -c . )" >> "$GITHUB_OUTPUT"
