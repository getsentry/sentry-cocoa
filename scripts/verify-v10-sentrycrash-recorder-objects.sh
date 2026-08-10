#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

BUILD_PATH=""

usage() {
  log_notice "Usage: $0"
  log_notice "  --build-path <path>    SwiftPM scratch path containing the V10 trait build (required)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-path)
      BUILD_PATH="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$BUILD_PATH" ]]; then
  log_error "Error: --build-path is required"
  usage
fi

if [[ ! -d "$BUILD_PATH" ]]; then
  log_error "Build path does not exist: $BUILD_PATH"
  exit 1
fi

candidate_count=0
violation_count=0

while IFS= read -r -d '' object_path; do
  case "$object_path" in
    */SentryCrash/Installations/* | \
      */SentryCrash/Reporting/* | \
      */SentryCrash/Recording/Monitors/* | \
      */SentryCrash/Recording/SentryCrash* | \
      */SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.* | \
      */Sentry/SentryCrashReportSink.* | \
      */Sentry/SentryCrashScopeObserver.*)
      candidate_count=$((candidate_count + 1))
      symbols="$(nm -gU "$object_path")"
      if [[ -n "$symbols" ]]; then
        log_error "Legacy recorder object defines external symbols: $object_path"
        printf '%s\n' "$symbols"
        violation_count=$((violation_count + 1))
      fi
      ;;
  esac
done < <(find "$BUILD_PATH" -type f -name '*.o' -print0)

if [[ $candidate_count -eq 0 ]]; then
  log_error "No legacy recorder translation units found under $BUILD_PATH; the audit did not run"
  exit 1
fi

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count legacy recorder object(s) define external symbols"
  exit 1
fi

log_notice "Verified $candidate_count legacy recorder translation units contain no external symbols"
