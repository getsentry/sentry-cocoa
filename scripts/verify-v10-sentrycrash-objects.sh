#!/bin/bash
set -euo pipefail

# Temporary development audit: certify that compiled legacy files emit no recorder
# implementation using the full log from the same successfully completed build.
# Artifact and runtime checks remain independent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

BUILD_PATH=""
BUILD_LOG=""
SOURCE_ROOT=""

usage() {
  log_info "Usage: $0 --build-path <path> --build-log <path> [--source-root <path>]"
  log_info "  --build-path, -b: completed build output to audit (required)"
  log_info "  --build-log, -l: full verbose log from that completed build (required)"
  log_info "  --source-root, -s: SDK source inventory root (default: repository)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || usage
  case $1 in
    --build-path|-b) BUILD_PATH="$2"; shift 2 ;;
    --build-log|-l) BUILD_LOG="$2"; shift 2 ;;
    --source-root|-s) SOURCE_ROOT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -z "$BUILD_PATH" || ! -d "$BUILD_PATH" ]]; then
  log_error "A valid --build-path is required"
  usage
fi
if [[ -z "$BUILD_LOG" || ! -f "$BUILD_LOG" ]]; then
  log_error "A valid --build-log is required"
  usage
fi

BUILD_PATH="$(cd "$BUILD_PATH" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
exec swift "$SCRIPT_DIR/verify-v10-empty-objects.swift" --build-path "$BUILD_PATH" \
  --build-log "$BUILD_LOG" --source-root "${SOURCE_ROOT:-$REPO_ROOT}"
