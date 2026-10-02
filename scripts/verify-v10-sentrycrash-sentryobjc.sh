#!/bin/bash
set -euo pipefail

# Audits every static-library or dynamic-framework slice in a V10 SentryObjC XCFramework. The
# wrapper packages a different public header surface than Sentry.framework, so this check enforces
# recorder absence without requiring Sentry.framework's SDK-side compatibility headers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""

usage() {
  log_info "Usage: $0 --xcframework-path <path>"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcframework-path)
      XCFRAMEWORK_PATH="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$XCFRAMEWORK_PATH" || ! -d "$XCFRAMEWORK_PATH" ]]; then
  log_error "A valid --xcframework-path is required"
  usage
fi

XCFRAMEWORK_PATH="$(cd "$XCFRAMEWORK_PATH" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFO_PLIST="$XCFRAMEWORK_PATH/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  log_error "XCFramework Info.plist does not exist: $INFO_PLIST"
  exit 1
fi

legacy_headers_path=$(mktemp)
slice_inventory_path=$(mktemp)
symbols_path=$(mktemp)
trap 'rm -f "$legacy_headers_path" "$slice_inventory_path" "$symbols_path"' EXIT

find "$REPO_ROOT/Sources/SentryCrashV9Headers/include" -type f \
  \( -name '*.h' -o -name '*.hpp' \) -exec basename {} \; | sort -u > "$legacy_headers_path"

python3 - "$XCFRAMEWORK_PATH" > "$slice_inventory_path" <<'PY'
from pathlib import Path
import plistlib
import sys

xcframework = Path(sys.argv[1])
with (xcframework / "Info.plist").open("rb") as file:
    info = plistlib.load(file)

for library in info.get("AvailableLibraries", []):
    identifier = library["LibraryIdentifier"]
    slice_root = xcframework / identifier
    library_path = slice_root / library["LibraryPath"]
    if library_path.suffix == ".framework":
        binary_path = library_path / library_path.stem
        headers_path = library_path / "Headers"
    else:
        binary_path = library_path
        headers_path = slice_root / library.get("HeadersPath", "Headers")
    print(f"{identifier}\t{binary_path}\t{headers_path}")
PY

if [[ ! -s "$slice_inventory_path" ]]; then
  log_error "XCFramework contains no library slices: $XCFRAMEWORK_PATH"
  exit 1
fi

forbidden_symbols=(
  sentrycrash_install
  sentrycrashcm_signal_getAPI
  sentrycrashcm_machexception_getAPI
  sentrycrashcm_cppexception_getAPI
  sentrycrashcm_nsexception_getAPI
  sentrycrashbic_startCache
  sentrycrashcrs_initialize
  sentrycrashdate_utcStringFromTimestamp
  sentrycrashdebug_isBeingTraced
  sentrycrashdl_initialize
  sentrycrashid_generate
  sentrycrash_macho_getCommandByTypeFromHeader
  sentrycrashmach_exceptionName
  sentryErrorWithDomain
  sentrycrashobjc_objectType
  sentrycrashsignal_signalName
  sentrycrashsc_initSelfThread
  sentrycrashsc_initWithBacktrace
  sentrycrashstring_extractHexValue
)
forbidden_objc_classes=(
  SentryCrash
  SentryCrashBridge
  SentryCrashInstallation
  SentryCrashJSONCodec
  SentryCrashReportSink
  SentryCrashScopeObserver
  SentryCrashSwift
  SentryDefaultCrashReporter
)

violation_count=0
slice_count=0
record_error() {
  log_error "$1"
  violation_count=$((violation_count + 1))
}

while IFS=$'\t' read -r identifier binary_path headers_path; do
  slice_count=$((slice_count + 1))
  if [[ ! -f "$binary_path" ]]; then
    record_error "SentryObjC slice binary is missing ($identifier): $binary_path"
    continue
  fi
  if [[ ! -d "$headers_path" ]]; then
    record_error "SentryObjC slice headers are missing ($identifier): $headers_path"
    continue
  fi

  if ! nm -arch all -gU "$binary_path" 2>/dev/null \
    | awk '{ print $NF }' | sed 's/^_//' | sort -u > "$symbols_path"; then
    record_error "Could not inspect SentryObjC slice symbols ($identifier): $binary_path"
    continue
  fi

  for symbol in "${forbidden_symbols[@]}"; do
    if grep -Fxq "$symbol" "$symbols_path"; then
      record_error "V10 SentryObjC slice contains recorder symbol ($identifier): $symbol"
    fi
  done
  for class_name in "${forbidden_objc_classes[@]}"; do
    if grep -Eq "^OBJC_CLASS_.*${class_name}$" "$symbols_path"; then
      record_error "V10 SentryObjC slice contains recorder class ($identifier): $class_name"
    fi
  done
  if ! grep -qE '^OBJC_CLASS_.*SentryObjCSDK$' "$symbols_path"; then
    record_error "SentryObjCSDK is missing from V10 wrapper slice: $identifier"
  fi

  while IFS= read -r forbidden_header; do
    if find "$headers_path" -type f -name "$forbidden_header" -print -quit | grep -q .; then
      record_error "V10 SentryObjC slice packages V9 recorder header ($identifier): $forbidden_header"
    fi
  done < "$legacy_headers_path"

  while IFS=: read -r packaged_header line_number directive; do
    imported_header=$(sed -E 's/^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*[<"]([^>"]+)[>"].*/\2/' <<< "$directive")
    imported_name=$(basename "$imported_header")
    if grep -Fxq "$imported_name" "$legacy_headers_path"; then
      record_error "V10 SentryObjC header imports recorder header $imported_name: $packaged_header:$line_number"
    fi
  done < <(
    grep -RInHE '^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*[<"][^>"]+[>"]' \
      "$headers_path" 2>/dev/null || true
  )

  if grep -RInE '^[[:space:]]*@(interface|protocol)[[:space:]]+(SentryCrash|SentryDefaultCrashReporter)([[:space:]:<(]|$)' \
    "$headers_path"; then
    record_error "V10 SentryObjC headers declare a V9 recorder interface: $identifier"
  fi
  if grep -RInE '^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef).*SDK_V10' "$headers_path"; then
    record_error "V10 SentryObjC headers retain an unresolved SDK_V10 gate: $identifier"
  fi

done < "$slice_inventory_path"

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count V10 SentryObjC packaging violation(s) found"
  exit 1
fi

log_info "Verified recorder exclusion in $slice_count V10 SentryObjC XCFramework slice(s)"
