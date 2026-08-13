#!/bin/bash
set -euo pipefail

# Final-product V10 migration contract. This audit takes a dynamic or static Sentry.framework and
# proves that linking and packaging expose the intended compatibility boundary.
#
# Verifies:
# - Proven recorder entry points and ObjC implementation classes are absent.
# - The C++ ABI compatibility symbols are exactly __sentry_cxa_throw and __sentry_cxa_rethrow.
# - All 15 SDK-owned sentrycrash_scopesync_* symbols and SentryCrashReportConverter remain present.
# - macOS retains the public SentryCrashExceptionApplication implementation and every platform
#   packages its public header.
# - Headers for excluded adapters are absent, packaged headers do not import legacy recorder
#   headers, and the generated Swift header does not declare excluded implementation classes.
#
# This enforces the linked and packaged result; source responsibility coverage and compiled-object
# provenance are enforced by the companion source-contract and object scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

FRAMEWORK_PATH=""

usage() {
  log_notice "Usage: $0"
  log_notice "  --framework-path <path>    V10 Sentry.framework to audit (required)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --framework-path)
      FRAMEWORK_PATH="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$FRAMEWORK_PATH" ]]; then
  log_error "Error: --framework-path is required"
  usage
fi
if [[ ! -d "$FRAMEWORK_PATH" ]]; then
  log_error "Framework path does not exist: $FRAMEWORK_PATH"
  exit 1
fi

FRAMEWORK_PATH="$(cd "$FRAMEWORK_PATH" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH" .framework)
BINARY_PATH="$FRAMEWORK_PATH/$FRAMEWORK_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
  log_error "Framework binary does not exist: $BINARY_PATH"
  exit 1
fi

symbols_path=$(mktemp)
legacy_headers_path=$(mktemp)
trap 'rm -f "$symbols_path" "$legacy_headers_path"' EXIT

if ! nm -gU "$BINARY_PATH" | awk '{ print $NF }' | sed 's/^_//' | sort -u > "$symbols_path"; then
  log_error "Could not inspect framework symbols: $BINARY_PATH"
  exit 1
fi

violation_count=0
record_error() {
  log_error "$1"
  violation_count=$((violation_count + 1))
}

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
  sentrycrashstring_extractHexValue
)
for symbol in "${forbidden_symbols[@]}"; do
  if grep -Fxq "$symbol" "$symbols_path"; then
    record_error "Legacy recorder symbol is present in V10: $symbol"
  fi
done

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
for class_name in "${forbidden_objc_classes[@]}"; do
  if grep -Eq "^OBJC_CLASS_.*${class_name}$" "$symbols_path"; then
    record_error "Legacy recorder class is present in V10: $class_name"
  fi
done

expected_compatibility_symbols=$(printf '%s\n' \
  __sentry_cxa_rethrow \
  __sentry_cxa_throw \
  | sort)
actual_compatibility_symbols=$(grep -E '^__sentry_cxa_' "$symbols_path" | sort || true)
if [[ "$actual_compatibility_symbols" != "$expected_compatibility_symbols" ]]; then
  record_error "V10 compatibility symbols differ from the exact allowlist"
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected_compatibility_symbols" "$actual_compatibility_symbols"
fi

expected_scope_sync_symbols=$(printf '%s\n' \
  sentrycrash_scopesync_addBreadcrumb \
  sentrycrash_scopesync_clear \
  sentrycrash_scopesync_clearBreadcrumbs \
  sentrycrash_scopesync_configureBreadcrumbs \
  sentrycrash_scopesync_getScope \
  sentrycrash_scopesync_reset \
  sentrycrash_scopesync_setContext \
  sentrycrash_scopesync_setDist \
  sentrycrash_scopesync_setEnvironment \
  sentrycrash_scopesync_setExtras \
  sentrycrash_scopesync_setFingerprint \
  sentrycrash_scopesync_setLevel \
  sentrycrash_scopesync_setTags \
  sentrycrash_scopesync_setTraceContext \
  sentrycrash_scopesync_setUser \
  | sort)
actual_scope_sync_symbols=$(grep -E '^sentrycrash_scopesync_' "$symbols_path" | sort || true)
if [[ "$actual_scope_sync_symbols" != "$expected_scope_sync_symbols" ]]; then
  record_error "SDK-owned scope-sync symbols are incomplete or unexpected"
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected_scope_sync_symbols" "$actual_scope_sync_symbols"
fi

if plutil -p "$FRAMEWORK_PATH/Info.plist" 2>/dev/null | grep -q 'MacOSX' \
  && ! grep -qE '^OBJC_CLASS_.*SentryCrashExceptionApplication$' "$symbols_path"; then
  record_error "Public macOS SentryCrashExceptionApplication compatibility class is missing"
fi
if [[ ! -f "$FRAMEWORK_PATH/Headers/SentryCrashExceptionApplication.h" ]]; then
  record_error "Public SentryCrashExceptionApplication header is missing"
fi
if ! grep -qE '^OBJC_CLASS_.*SentryCrashReportConverter$' "$symbols_path"; then
  record_error "SDK-owned SentryCrashReportConverter is missing"
fi

for forbidden_header in SentryCrashReportSink.h SentryCrashScopeObserver.h; do
  if find "$FRAMEWORK_PATH/Headers" "$FRAMEWORK_PATH/PrivateHeaders" \
    -type f -name "$forbidden_header" -print -quit 2>/dev/null | grep -q .; then
    record_error "V10 packages a header for an absent implementation: $forbidden_header"
  fi
done

{
  find "$REPO_ROOT/Sources/SentryCrash" -type f \( -name '*.h' -o -name '*.hpp' \) \
    -exec basename {} \;
  find "$REPO_ROOT/Sources/Sentry/include" -type f -name 'SentryCrash*.h' -exec basename {} \;
} \
  | grep -vE '^(SentryCrashExceptionApplication|SentryCrashDefaultMachineContextWrapper|SentryCrashIsAppImage|SentryCrashMachineContextWrapper|SentryCrashReportConverter|SentryCrashStackEntryMapper)\.h$' \
  | sort -u > "$legacy_headers_path"

while IFS=: read -r packaged_header line_number directive; do
  imported_header=$(sed -E 's/^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*[<"]([^>"]+)[>"].*/\2/' <<< "$directive")
  imported_name=$(basename "$imported_header")
  if grep -Fxq "$imported_name" "$legacy_headers_path"; then
    record_error "Packaged V10 header imports legacy recorder header $imported_name: $packaged_header:$line_number"
  fi
done < <(
  grep -RInHE '^[[:space:]]*#[[:space:]]*(import|include)[[:space:]]*[<"][^>"]+[>"]' \
    "$FRAMEWORK_PATH/Headers" "$FRAMEWORK_PATH/PrivateHeaders" 2>/dev/null || true
)

swift_header="$FRAMEWORK_PATH/Headers/$FRAMEWORK_NAME-Swift.h"
if [[ -f "$swift_header" ]]; then
  for class_name in "${forbidden_objc_classes[@]}"; do
    if grep -Eq "^@interface ${class_name}([[:space:]]|:)" "$swift_header"; then
      record_error "Generated V10 header declares absent class: $class_name"
    fi
  done
fi

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count V10 SentryCrash framework violation(s) found"
  exit 1
fi

log_notice "Verified V10 framework symbols, compatibility contracts, scope sync, and headers"
