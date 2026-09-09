#!/bin/bash
set -euo pipefail

# Compiled-object V10 migration contract. This audit takes an Xcode or SwiftPM build directory and
# proves that compilation followed the reviewed source classification.
#
# Verifies:
# - Every Tool in Sources/Configuration/SentryCrashV10ToolSources.xcconfig exists, is unique, and
#   produced an object in the audited build.
# - No recorder source, excluded Tool, or excluded SDK-owned V9 adapter produced a normal V10
#   object.
# - SwiftPM trait builds may contain only the unavoidable whole-file !SDK_V10 guarded translation
#   units, and each such object exports no external symbol.
#
# This does not prove that final linking, dead stripping, or framework packaging preserved the
# intended API. That layer is enforced by verify-v10-sentrycrash-framework.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

BUILD_PATH=""
ALLOW_EMPTY_TRANSLATION_UNITS=false

usage() {
  log_notice "Usage: $0"
  log_notice "  --build-path <path>                 V10 build output to audit (required)"
  log_notice "  --allow-empty-translation-units    Allow SDK_V10-guarded legacy files emitted by SwiftPM traits"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-path)
      BUILD_PATH="$2"
      shift 2
      ;;
    --allow-empty-translation-units)
      ALLOW_EMPTY_TRANSLATION_UNITS=true
      shift
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

BUILD_PATH="$(cd "$BUILD_PATH" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOWLIST_PATH="$REPO_ROOT/Sources/Configuration/SentryCrashV10ToolSources.xcconfig"
ALLOWLIST_SETTING="SENTRYCRASH_V10_RETAINED_TOOL_SOURCE_FILE_NAMES"
TOOLS_SOURCE_PATH="Sources/SentryCrash/Recording/Tools"

if [[ ! -f "$ALLOWLIST_PATH" ]]; then
  log_error "V10 SentryCrash Tool source allowlist does not exist: $ALLOWLIST_PATH"
  exit 1
fi

allowlist_assignment_count=$(grep -c "^${ALLOWLIST_SETTING} = " "$ALLOWLIST_PATH" || true)
if [[ "$allowlist_assignment_count" -ne 1 ]]; then
  log_error "Expected exactly one $ALLOWLIST_SETTING assignment in $ALLOWLIST_PATH"
  exit 1
fi

allowlist_assignment=$(grep "^${ALLOWLIST_SETTING} = " "$ALLOWLIST_PATH")
allowlist_value=${allowlist_assignment#*= }
read -r -a ALLOWED_SOURCE_NAMES <<< "$allowlist_value"

contains_value() {
  local expected="$1"
  shift
  local value
  for value in "$@"; do
    if [[ "$value" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

validated_allowed_source_names=()
for source_name in "${ALLOWED_SOURCE_NAMES[@]}"; do
  if contains_value "$source_name" "${validated_allowed_source_names[@]+${validated_allowed_source_names[@]}}"; then
    log_error "Duplicate V10 SentryCrash Tool source allowlist entry: $source_name"
    exit 1
  fi
  if [[ ! -f "$REPO_ROOT/$TOOLS_SOURCE_PATH/$source_name" ]]; then
    log_error "V10 SentryCrash Tool source allowlist entry does not exist: $source_name"
    exit 1
  fi
  validated_allowed_source_names+=("$source_name")
done

if [[ ${#validated_allowed_source_names[@]} -eq 0 ]]; then
  log_error "V10 SentryCrash Tool source allowlist is empty"
  exit 1
fi

SOURCE_PATHS=()
XCODE_OBJECT_NAMES=()
SWIFTPM_OBJECT_NAMES=()

add_source_mapping() {
  local source_path="$1"
  local source_name
  local source_stem
  source_name=$(basename "$source_path")
  source_stem=${source_name%.*}

  SOURCE_PATHS+=("$source_path")
  XCODE_OBJECT_NAMES+=("$source_stem.o")
  SWIFTPM_OBJECT_NAMES+=("$source_name.o")
}

while IFS= read -r source_path; do
  add_source_mapping "${source_path#"$REPO_ROOT/"}"
done < <(find "$REPO_ROOT/Sources/SentryCrash" -type f \
  \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.m' -o -name '*.mm' \) \
  -print | sort)

for source_path in \
  Sources/Sentry/SentryCrashReportSink.m \
  Sources/Sentry/SentryCrashScopeObserver.m; do
  add_source_mapping "$source_path"
done

RESOLVED_SOURCE_PATH=""
resolve_source_path() {
  local object_name="$1"
  local index
  RESOLVED_SOURCE_PATH=""

  for index in "${!SOURCE_PATHS[@]}"; do
    if [[ "$object_name" == "${XCODE_OBJECT_NAMES[$index]}" \
      || "$object_name" == "${SWIFTPM_OBJECT_NAMES[$index]}" ]]; then
      RESOLVED_SOURCE_PATH="${SOURCE_PATHS[$index]}"
      return 0
    fi
  done
  return 1
}

is_allowed_source() {
  local source_path="$1"
  local source_name
  source_name=$(basename "$source_path")

  [[ "$source_path" == "$TOOLS_SOURCE_PATH/$source_name" ]] \
    && contains_value "$source_name" "${validated_allowed_source_names[@]}"
}

candidate_object_count=0
violation_count=0
empty_translation_unit_count=0
compiled_allowed_source_names=()

while IFS= read -r -d '' object_path; do
  object_name=$(basename "$object_path")
  if ! resolve_source_path "$object_name"; then
    continue
  fi

  candidate_object_count=$((candidate_object_count + 1))
  source_path="$RESOLVED_SOURCE_PATH"

  if is_allowed_source "$source_path"; then
    source_name=$(basename "$source_path")
    if ! contains_value "$source_name" "${compiled_allowed_source_names[@]+${compiled_allowed_source_names[@]}}"; then
      compiled_allowed_source_names+=("$source_name")
    fi
    continue
  fi

  if [[ "$ALLOW_EMPTY_TRANSLATION_UNITS" != true ]]; then
    log_error "Non-allowlisted legacy source compiled in V10: $source_path ($object_path)"
    violation_count=$((violation_count + 1))
    continue
  fi

  if ! grep -qE '^#if[[:space:]]+!SDK_V10[[:space:]]*$' "$REPO_ROOT/$source_path"; then
    log_error "Non-allowlisted trait source lacks a whole-file SDK_V10 guard: $source_path"
    violation_count=$((violation_count + 1))
    continue
  fi

  if ! symbols=$(nm -gU "$object_path"); then
    log_error "Could not inspect legacy object: $object_path"
    violation_count=$((violation_count + 1))
    continue
  fi
  if [[ -n "$symbols" ]]; then
    log_error "SDK_V10-guarded legacy object defines external symbols: $object_path"
    printf '%s\n' "$symbols"
    violation_count=$((violation_count + 1))
    continue
  fi

  empty_translation_unit_count=$((empty_translation_unit_count + 1))
done < <(find "$BUILD_PATH" -type f -name '*.o' -print0)

if [[ $candidate_object_count -eq 0 ]]; then
  log_error "No SentryCrash source objects found under $BUILD_PATH; the audit did not run"
  exit 1
fi

for source_name in "${validated_allowed_source_names[@]}"; do
  if ! contains_value "$source_name" "${compiled_allowed_source_names[@]+${compiled_allowed_source_names[@]}}"; then
    log_error "Allowlisted V10 SentryCrash Tool source did not compile: $source_name"
    violation_count=$((violation_count + 1))
  fi
done

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count V10 SentryCrash source object violation(s) found"
  exit 1
fi

log_notice "Verified ${#compiled_allowed_source_names[@]} retained SentryCrash Tool sources"
if [[ "$ALLOW_EMPTY_TRANSLATION_UNITS" == true ]]; then
  log_notice "Verified $empty_translation_unit_count SDK_V10-guarded legacy objects contain no external symbols"
fi
