#!/bin/bash
set -euo pipefail

# Script to replace sentry-cocoa remote dependency with local path in integration packages
# This is useful for CI testing where we want to test integrations against the current code

usage() {
  cat <<'USAGE'
Usage: prepare-package.sh [options]

Options:
  --package-file PATH            Path to the Package.swift file (default: Package.swift)
  --path-to-sentry-cocoa PATH    Path to the sentry-cocoa directory (default: ../../../sentry-cocoa)
  -h, --help                     Show this help message
USAGE
}

PACKAGE_FILE="Package.swift"
PATH_TO_SENTRY_COCOA="../../../"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-file)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      PACKAGE_FILE="$2"
      shift 2
      ;;
    --path-to-sentry-cocoa)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      PATH_TO_SENTRY_COCOA="$2"
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

echo "Updating $PACKAGE_FILE to use local sentry-cocoa dependency..."

# Replace the sentry-cocoa dependency line
# Matches: .package(url: "https://github.com/getsentry/sentry-cocoa", from: "X.Y.Z")
# With: .package(path: "../../..")
sed -i '' \
    -e 's|\.package(url: "https://github\.com/getsentry/sentry-cocoa", from: "[^"]*")|.package(path: "'"$PATH_TO_SENTRY_COCOA"'")|g' \
    "$PACKAGE_FILE"

echo "✓ Successfully updated dependency to use local path: $PATH_TO_SENTRY_COCOA"
