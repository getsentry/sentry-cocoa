#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: prepare-package.sh [options]

Options:
  --package-file PATH        Path to the Package.swift file (default: Package.swift)
  --is-pr true|false         Whether this run simulates a pull request (default: false)
  --remove-duplicate true|false
                             Whether to strip duplicate targets (default: false)
  --change-path true|false   Whether to swap SPM binary URLs for local paths (default: false)
  --remove-binary-targets true|false
                             Whether to keep only SentryDistribution product/target (default: false)
  --update-path-to-sentry-cocoa true|false
                             Whether to update the path to the sentry-cocoa directory (default: false)
  -h, --help                 Show this help message
USAGE
}

is_enabled() {
  case "$1" in
    true|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

PACKAGE_FILE="Package.swift"
IS_PR="false"
REMOVE_DUPLICATE="false"
CHANGE_PATH="false"
REMOVE_BINARY_TARGETS="false"
UPDATE_PATH_TO_SENTRY_COCOA="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-file)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      PACKAGE_FILE="$2"
      shift 2
      ;;
    --is-pr)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      IS_PR="$2"
      shift 2
      ;;
    --remove-duplicate)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      REMOVE_DUPLICATE="$2"
      shift 2
      ;;
    --change-path)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      CHANGE_PATH="$2"
      shift 2
      ;;
    --remove-binary-targets)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      REMOVE_BINARY_TARGETS="$2"
      shift 2
      ;;
    --update-path-to-sentry-cocoa)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      UPDATE_PATH_TO_SENTRY_COCOA="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$PACKAGE_FILE" ]]; then
  echo "Package file not found: $PACKAGE_FILE" >&2
  exit 1
fi

if is_enabled "$IS_PR"; then
  # Remove Sentry-Dynamic-WithARM64e target definitions and clean up empty binary blocks.
  sed -i '' '/Sentry-Dynamic-WithARM64e/d' "$PACKAGE_FILE"
  sed -i '' '/Sentry-WithoutUIKitOrAppKit-WithARM64e/d' "$PACKAGE_FILE"
  sed -i '' '/^[[:space:]]*\.binaryTarget($/{N;/\n[[:space:]]*),\{0,1\}$/d;}' "$PACKAGE_FILE"
fi

if is_enabled "$REMOVE_DUPLICATE"; then
  sed -i '' '/Sentry-Dynamic/d' "$PACKAGE_FILE"
  sed -i '' '/Sentry-WithoutUIKitOrAppKit/d' "$PACKAGE_FILE"
  sed -i '' '/^[[:space:]]*\.binaryTarget($/{N;/\n[[:space:]]*),\{0,1\}$/d;}' "$PACKAGE_FILE"
fi

if is_enabled "$CHANGE_PATH"; then
  # Remove Sentry binary framework URLs and convert checksums to local paths.
  sed -i '' 's/url: "https:\/\/github\.com\/getsentry\/sentry-cocoa\/releases\/download\/.*"//g' "$PACKAGE_FILE"
  sed -i '' 's/checksum: ".*" \/\/Sentry-Static/path: "Sentry.xcframework.zip"/g' "$PACKAGE_FILE"
  sed -i '' 's/checksum: ".*" \/\/Sentry-Dynamic-WithARM64e/path: "Sentry-Dynamic-WithARM64e.xcframework.zip"/g' "$PACKAGE_FILE"
  sed -i '' 's/checksum: ".*" \/\/Sentry-Dynamic/path: "Sentry-Dynamic.xcframework.zip"/g' "$PACKAGE_FILE"
  sed -i '' 's/checksum: ".*" \/\/Sentry-WithoutUIKitOrAppKit-WithARM64e/path: "Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip"/g' "$PACKAGE_FILE"
  sed -i '' 's/checksum: ".*" \/\/Sentry-WithoutUIKitOrAppKit/path: "Sentry-WithoutUIKitOrAppKit.xcframework.zip"/g' "$PACKAGE_FILE"

  # Clean up orphaned commas and fix syntax.
  sed -i '' '/^[[:space:]]*,$/d' "$PACKAGE_FILE"
  sed -i '' 's/name: "Sentry\(-.*\)\?"$/name: "Sentry\1",/g' "$PACKAGE_FILE"
  sed -i '' 's/platforms: \[\.iOS(\.v11), \.macOS(\.v10_13), \.tvOS(\.v11), \.watchOS(\.v4)\]$/platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],/g' "$PACKAGE_FILE"
fi

if is_enabled "$REMOVE_BINARY_TARGETS"; then
  # Remove all binary targets.
  sed -i '' '/^[[:space:]]*\.binaryTarget(/,/^[[:space:]]*),\{0,1\}$/d' "$PACKAGE_FILE"

  # Keep only the SentryDistribution library in the products array.
  sed -i '' '/^var products: \[Product\] = \[/,/^]/c\
var products: [Product] = [\
    .library(name: "SentryDistribution", targets: ["SentryDistribution"]),\
]\
' "$PACKAGE_FILE"

  # Keep only the SentryDistribution target in the targets array.
  sed -i '' '/^var targets: \[Target\] = \[/,/^]/c\
var targets: [Target] = [\
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),\
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")\
]\
' "$PACKAGE_FILE"

  # Replace dependency declarations with an empty list.
  sed -i '' '/^    dependencies: \[/,/^    ],/c\
    dependencies: [],\
' "$PACKAGE_FILE"

  # Remove conditional append blocks that reintroduce other targets/products.
  sed -i '' '/^let env = getenv("EXPERIMENTAL_SPM_BUILDS")/,/^}/d' "$PACKAGE_FILE"
fi

if is_enabled "$UPDATE_PATH_TO_SENTRY_COCOA"; then
  sed -i '' 's|\.package(url: "https://github\.com/getsentry/sentry-cocoa", from: "[^"]*")|.package(path: "'../../'")|g' "$PACKAGE_FILE"
fi

echo
echo "===== $PACKAGE_FILE (after prepare-package.sh) ====="
cat "$PACKAGE_FILE"
echo "===== end of $PACKAGE_FILE (after prepare-package.sh) ====="
echo
