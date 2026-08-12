#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

usage() {
  log_notice "Usage: $0"
  log_notice "Verifies the repository-level V10 SentryCrash migration contract."
  exit 1
}

if [[ $# -ne 0 ]]; then
  usage
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEDGER_PATH="$REPO_ROOT/develop-docs/SENTRYCRASH_V10_MIGRATION_LEDGER.md"
TOOLS_ALLOWLIST_PATH="$REPO_ROOT/Sources/Configuration/SentryCrashV10ToolSources.xcconfig"
V10_XCCONFIG_PATH="$REPO_ROOT/Sources/Configuration/SentryV10.xcconfig"
cd "$REPO_ROOT"

violation_count=0
record_error() {
  log_error "$1"
  violation_count=$((violation_count + 1))
}

if [[ ! -f "$LEDGER_PATH" ]]; then
  log_error "Migration ledger does not exist: $LEDGER_PATH"
  exit 1
fi

ledger_ids=()
while IFS= read -r ledger_id; do
  ledger_ids+=("$ledger_id")
done < <(awk -F '|' '/^\| SCV10-[0-9][0-9][0-9] / { gsub(/ /, "", $2); print $2 }' "$LEDGER_PATH")
if [[ ${#ledger_ids[@]} -eq 0 ]]; then
  log_error "Migration ledger has no SCV10 entries"
  exit 1
fi

if duplicates=$(printf '%s\n' "${ledger_ids[@]}" | sort | uniq -d) && [[ -n "$duplicates" ]]; then
  record_error "Duplicate migration ledger IDs: $duplicates"
fi

while IFS= read -r ledger_row; do
  ledger_id=$(awk -F '|' '{ gsub(/ /, "", $2); print $2 }' <<< "$ledger_row")
  status=$(awk -F '|' '{ print $6 }' <<< "$ledger_row")
  if [[ ! "$status" =~ working|temporary|decision ]]; then
    record_error "$ledger_id has no working, temporary, or decision status"
  fi
done < <(grep -E '^\| SCV10-[0-9]{3} ' "$LEDGER_PATH")

ledger_contains_id() {
  local acceptance_id="$1"
  grep -qE "^\\| ${acceptance_id} " "$LEDGER_PATH"
}

conditional_block() {
  local source_path="$1"
  local start_line="$2"

  awk -v start_line="$start_line" '
    NR < start_line { next }
    {
      if ($0 ~ /^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef)([[:space:]]|$)/) {
        depth++
      }
      print
      if ($0 ~ /^[[:space:]]*#[[:space:]]*endif([[:space:]]|$)/) {
        depth--
        if (depth == 0) {
          exit
        }
      }
    }
  ' "$source_path"
}

verify_marker_blocks() {
  local search_path="$1"
  local marker_kind="$2"
  local marker_count=0

  while IFS=: read -r source_path line_number _; do
    marker_count=$((marker_count + 1))
    block=$(conditional_block "$source_path" "$line_number")

    if ! grep -q 'KSCRASH_TODO(GH-' <<< "$block"; then
      record_error "$marker_kind marker lacks a KSCRASH_TODO with a tracker: $source_path:$line_number"
    fi

    acceptance_ids=()
    while IFS= read -r acceptance_id; do
      acceptance_ids+=("$acceptance_id")
    done < <(grep -oE 'SCV10-[0-9]{3}' <<< "$block" | sort -u || true)
    if [[ ${#acceptance_ids[@]} -eq 0 ]]; then
      record_error "$marker_kind marker lacks a migration-ledger acceptance ID: $source_path:$line_number"
      continue
    fi

    for acceptance_id in "${acceptance_ids[@]}"; do
      if ! ledger_contains_id "$acceptance_id"; then
        record_error "$source_path:$line_number references unknown acceptance ID $acceptance_id"
      fi
    done
  done < <(rg -n --no-heading \
    '^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef).*SENTRY_DISABLE_SENTRYCRASH_V10' \
    "$search_path" --glob '!Configuration/**')

  if [[ $marker_count -eq 0 ]]; then
    record_error "No $marker_kind migration markers found under $search_path; the marker audit did not run"
  else
    log_notice "Verified $marker_count annotated $marker_kind migration marker blocks"
  fi
}

verify_marker_blocks Sources production
verify_marker_blocks Tests/SentryTests test

legacy_headers_path=$(mktemp)
dependency_files_path=$(mktemp)
trap 'rm -f "$legacy_headers_path" "$dependency_files_path"' EXIT

find Sources/SentryCrash -type f \( -name '*.h' -o -name '*.hpp' \) -exec basename {} \; \
  | sort -u > "$legacy_headers_path"

while IFS= read -r header_name; do
  rg -l "[<\"]${header_name}[>\"]" Sources/Sentry Sources/Swift Sources/SentryCppHelper \
    --glob '*.{h,hpp,c,cc,cpp,m,mm,swift}' || true
done < "$legacy_headers_path" >> "$dependency_files_path"

# Historical SDK include paths also contain declarations for implementations under Sources/SentryCrash.
# Treat the name as audit input only; the ledger records whether each dependency is legacy or SDK-owned.
rg -l '^[[:space:]]*#[[:space:]]*(include|import)[[:space:]]*[<"]SentryCrash' \
  Sources/Sentry Sources/Swift Sources/SentryCppHelper \
  --glob '*.{h,hpp,c,cc,cpp,m,mm,swift}' >> "$dependency_files_path" || true

rg -n --no-heading '\bsentrycrash[A-Za-z0-9_]*[[:space:]]*\(' \
  Sources/Sentry Sources/Swift Sources/SentryCppHelper \
  --glob '*.{h,hpp,c,cc,cpp,m,mm,swift}' \
  | grep -v 'sentrycrash_scopesync_' \
  | cut -d: -f1 >> "$dependency_files_path" || true

dependency_files=()
while IFS= read -r dependency_file; do
  dependency_files+=("$dependency_file")
done < <(
  sort -u "$dependency_files_path" \
    | grep -v '^Sources/Sentry/include/' \
    | grep -v '^Sources/Sentry/SentryScopeSyncC.c$'
)

if [[ ${#dependency_files[@]} -eq 0 ]]; then
  record_error "No SDK-owned SentryCrash implementation dependencies found; the source audit did not run"
else
  for source_path in "${dependency_files[@]}"; do
    source_name=$(basename "$source_path")
    source_stem=${source_name%.*}
    if ! grep -Fq "$source_stem" "$LEDGER_PATH"; then
      record_error "SDK-owned dependency is missing from the migration ledger: $source_path"
    fi
  done
  log_notice "Verified ${#dependency_files[@]} SDK-owned dependency files are represented in the migration ledger"
fi

sdk_owned_excluded_sources=(
  Sources/Sentry/SentryCrashReportSink.m
  Sources/Sentry/SentryCrashScopeObserver.m
  Sources/Swift/Integrations/SentryCrash/SentryCrashBridge.swift
  Sources/Swift/Integrations/SentryCrash/SentryCrashInstallationReporter.swift
  Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift
  Sources/Swift/Integrations/SentryCrash/SentryCrashIntegrationSessionHandler.swift
  Sources/Swift/SentryCrash/SentryCrashSwift.swift
  Sources/Swift/SentryCrash/SentryDefaultCrashReporter.swift
)

classified_sdk_owned_exclusions=$(printf '%s\n' "${sdk_owned_excluded_sources[@]}" | sort)
actual_sdk_owned_exclusions=$(
  printf '%s\n' \
    Sources/Sentry/SentryCrashReportSink.m \
    Sources/Sentry/SentryCrashScopeObserver.m \
    Sources/Swift/SentryCrash/SentryCrashSwift.swift \
    Sources/Swift/SentryCrash/SentryDefaultCrashReporter.swift
  find Sources/Swift/Integrations/SentryCrash -maxdepth 1 -type f -print
)
actual_sdk_owned_exclusions=$(sort -u <<< "$actual_sdk_owned_exclusions")
if [[ "$actual_sdk_owned_exclusions" != "$classified_sdk_owned_exclusions" ]]; then
  record_error "SDK-owned V10 source exclusions differ from the migration-ledger classification"
fi

for source_path in "${sdk_owned_excluded_sources[@]}"; do
  source_name=$(basename "$source_path")
  source_stem=${source_name%.*}
  if [[ ! -f "$source_path" ]]; then
    record_error "Classified SDK-owned exclusion does not exist: $source_path"
  elif ! grep -Fq "$source_stem" "$LEDGER_PATH"; then
    record_error "SDK-owned exclusion is missing from the migration ledger: $source_path"
  fi
done

xcode_sources_root="\$(SRCROOT)/Sources"
expected_xcode_exclusions=$(printf '%s\n' \
  "$xcode_sources_root/Sentry/SentryCrashReportSink.m" \
  "$xcode_sources_root/Sentry/SentryCrashScopeObserver.m" \
  "$xcode_sources_root/Swift/Integrations/SentryCrash/*" \
  "$xcode_sources_root/Swift/SentryCrash/SentryCrashSwift.swift" \
  "$xcode_sources_root/Swift/SentryCrash/SentryDefaultCrashReporter.swift" \
  | sort)
actual_xcode_exclusions=$(
  grep '^EXCLUDED_SOURCE_FILE_NAMES = ' "$V10_XCCONFIG_PATH" \
    | tr ' ' '\n' \
    | grep -F "$xcode_sources_root/" \
    | grep -Fv "$xcode_sources_root/SentryCrash/" \
    | sort
)
if [[ "$actual_xcode_exclusions" != "$expected_xcode_exclusions" ]]; then
  record_error "V10 Xcode SDK-owned exclusions differ from the classified set"
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected_xcode_exclusions" "$actual_xcode_exclusions"
fi

expected_swift_package_exclusions=$(printf '%s\n' \
  Integrations/SentryCrash \
  SentryCrash/SentryCrashSwift.swift \
  SentryCrash/SentryDefaultCrashReporter.swift \
  | sort)
expected_objc_package_exclusions=$(printf '%s\n' \
  Sentry/SentryCrashReportSink.m \
  Sentry/SentryCrashScopeObserver.m \
  | sort)

for manifest_path in Package.swift Package@swift-6.1.swift Package@swift-6.2.swift; do
  actual_swift_package_exclusions=$(
    awk '
      /let sentrySwiftExcludes = enableV10 \? \[/ { inside = 1; next }
      inside && /^\] : \[\]/ { exit }
      inside { print }
    ' "$manifest_path" \
      | grep -oE '"[^"]+"' \
      | tr -d '"' \
      | sort
  )
  if [[ "$actual_swift_package_exclusions" != "$expected_swift_package_exclusions" ]]; then
    record_error "$manifest_path Swift V10 exclusions differ from the classified set"
  fi

  actual_objc_package_exclusions=$(
    awk '
      /sentryObjCInternalExcludes \+= v10ExcludedSentryCrashToolSources \+ \[/ { inside = 1; next }
      inside && /^[[:space:]]*\]/ { exit }
      inside { print }
    ' "$manifest_path" \
      | grep -oE '"[^"]+"' \
      | tr -d '"' \
      | grep '^Sentry/' \
      | sort
  )
  if [[ "$actual_objc_package_exclusions" != "$expected_objc_package_exclusions" ]]; then
    record_error "$manifest_path ObjC V10 exclusions differ from the classified set"
  fi
done
log_notice "Verified SDK-owned V10 exclusions use the classified Xcode and SwiftPM sets"

if rg -q 'SentryScopeSyncC\.c' "$V10_XCCONFIG_PATH" Package.swift Package@swift-6.1.swift Package@swift-6.2.swift; then
  record_error "SDK-owned SentryScopeSyncC.c must not be excluded from a V10 route"
fi
if rg -q '^#if[[:space:]]+!SDK_V10[[:space:]]*$' Sources/Sentry/SentryScopeSyncC.c; then
  record_error "SDK-owned SentryScopeSyncC.c must not have a whole-file V10 guard"
fi

allowlist_assignment=$(grep '^SENTRYCRASH_V10_RETAINED_TOOL_SOURCE_FILE_NAMES = ' "$TOOLS_ALLOWLIST_PATH")
read -r -a retained_tool_sources <<< "${allowlist_assignment#*= }"
for source_name in "${retained_tool_sources[@]}"; do
  if ! grep -Fq "$source_name" "$LEDGER_PATH"; then
    record_error "Retained Tool source is missing from the migration ledger: $source_name"
  fi
done
log_notice "Verified ${#retained_tool_sources[@]} retained Tool sources are documented"

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count V10 SentryCrash source-contract violation(s) found"
  exit 1
fi

log_notice "Verified the V10 SentryCrash source, marker, ownership, and ledger contract"
