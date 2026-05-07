#!/usr/bin/env bash

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Prepare Package.swift files for CI builds by stripping or rewriting
targets, paths, and binary definitions.

OPTIONS:
    --package-file PATH              Single Package.swift file (default: all discovered)
    --is-pr true|false               Strip arm64e targets for PR builds (default: false)
    --remove-duplicate true|false    Strip duplicate variant targets (default: false)
    --change-path true|false         Swap binary URLs for local paths (default: false)
    --remove-binary-targets true|false
                                     Keep only SentryDistribution (default: false)
    -h, --help                       Show this help message

EXAMPLES:
    $(basename "$0") --is-pr true
    $(basename "$0") --package-file Package.swift --change-path true
    $(basename "$0") --remove-binary-targets true

EOF
    exit 1
}

is_enabled() {
  case "$1" in
    true|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# Discover all Package@swift-*.swift files in the current directory (repo root). Sorted for deterministic order.
discover_package_files() {
  local list=("Package.swift")
  local swift_packages
  swift_packages=$(find . -maxdepth 1 -name 'Package@swift-*.swift' 2>/dev/null | sort)
  while IFS= read -r f; do
    if [[ -n "$f" ]]; then
      list+=("${f#./}")   # strip leading ./ for consistent names
    fi
  done <<< "$swift_packages"
  printf '%s\n' "${list[@]}"
}

# Default: discover all package files (override with --package-file for a single file)
PACKAGE_FILES=()
IS_PR="false"
REMOVE_DUPLICATE="false"
CHANGE_PATH="false"
REMOVE_BINARY_TARGETS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-file)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      PACKAGE_FILES=("$2")
      shift 2
      ;;
    --is-pr)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      IS_PR="$2"
      shift 2
      ;;
    --remove-duplicate)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      REMOVE_DUPLICATE="$2"
      shift 2
      ;;
    --change-path)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      CHANGE_PATH="$2"
      shift 2
      ;;
    --remove-binary-targets)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      REMOVE_BINARY_TARGETS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# When no --package-file was given, discover Package.swift and all Package@swift-*.swift
if [[ ${#PACKAGE_FILES[@]} -eq 0 ]]; then
  PACKAGE_FILES=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && PACKAGE_FILES+=("$f")
  done < <(discover_package_files)
fi

for PACKAGE_FILE in "${PACKAGE_FILES[@]}"; do
  if [[ ! -f "$PACKAGE_FILE" ]]; then
    log_error "Package file not found: $PACKAGE_FILE"
    exit 1
  fi
done

echo "Preparing package files:"
echo "  Files:                ${PACKAGE_FILES[*]}"
echo "  Is PR:                $IS_PR"
echo "  Remove duplicate:     $REMOVE_DUPLICATE"
echo "  Change path:          $CHANGE_PATH"
echo "  Remove binary targets: $REMOVE_BINARY_TARGETS"

for PACKAGE_FILE in "${PACKAGE_FILES[@]}"; do
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
  fi

  begin_group "$PACKAGE_FILE (after prepare-package.sh)"
  cat "$PACKAGE_FILE"
  end_group
done
