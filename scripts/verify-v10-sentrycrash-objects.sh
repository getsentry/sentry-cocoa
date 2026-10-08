#!/bin/bash
set -euo pipefail

# V10 must not emit or activate the legacy recorder implementation. Before V9 branches off,
# --build-log lets the audit verify that compiled legacy files emit no recorder implementation.
# Artifact audits remain independent: linker stripping alone does not certify isolation.
#
# Without --build-log, reject legacy sources, header dependencies and object files.
# Checking that compiled legacy files contain no recorder implementation requires the log.
# For XCFramework builds, pass the producer's DerivedData root so both archive intermediates
# and Mac Catalyst's non-archive build output are covered.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

BUILD_PATH=""
BUILD_LOG=""
SOURCE_ROOT=""
SPM_TARGETS=()

usage() {
  log_info "Usage: $0 --build-path <path> [--build-log <path>] [--spm-target <target> ...]"
  log_info "  --build-path, -b: completed build output to audit (required)"
  log_info "  --spm-target, -t: actual requested target; repeat for native SwiftPM builds"
  log_info "  --build-log, -l: full verbose log from a completed build; permits verified implementation-free legacy objects"
  log_info "  --source-root, -s: SDK source inventory root (default: repository; requires build log)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-path|-b)
      [[ $# -ge 2 ]] || usage
      BUILD_PATH="$2"
      shift 2
      ;;
    --build-log|-l)
      [[ $# -ge 2 ]] || usage
      BUILD_LOG="$2"
      shift 2
      ;;
    --source-root|-s)
      [[ $# -ge 2 ]] || usage
      SOURCE_ROOT="$2"
      shift 2
      ;;
    --spm-target|-t)
      [[ $# -ge 2 ]] || usage
      [[ -n "$2" ]] || usage
      SPM_TARGETS+=(--spm-target "$2")
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$BUILD_PATH" || ! -d "$BUILD_PATH" ]]; then
  log_error "A valid --build-path is required"
  usage
fi

BUILD_PATH="$(cd "$BUILD_PATH" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "$BUILD_LOG" ]]; then
  [[ -f "$BUILD_LOG" ]] || { log_error "Missing build log: $BUILD_LOG"; exit 1; }
  exec swift "$SCRIPT_DIR/verify-v10-empty-objects.swift" --build-path "$BUILD_PATH" \
    --build-log "$BUILD_LOG" --source-root "${SOURCE_ROOT:-$REPO_ROOT}"
fi
[[ -z "$SOURCE_ROOT" ]] || usage

# No build log was supplied. Reject legacy files rather than trying to determine
# whether their compiled objects contain recorder implementation.
forbidden_sources=()
while IFS= read -r source_path; do
  forbidden_sources+=("${source_path#"$REPO_ROOT/"}")
done < <(find "$REPO_ROOT/Sources/SentryCrash" -type f \
  \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.m' -o -name '*.mm' \) \
  -print | sort)
while IFS= read -r source_path; do
  forbidden_sources+=("${source_path#"$REPO_ROOT/"}")
done < <(find "$REPO_ROOT/Sources/SentryCrashV9Swift" -type f -name '*.swift' -print | sort)
forbidden_sources+=(
  Sources/Sentry/SentryCrashDefaultMachineContextWrapper.m
  Sources/Sentry/SentryCrashReportSink.m
  Sources/Sentry/SentryCrashScopeObserver.m
)

forbidden_headers=()
while IFS= read -r header_path; do
  forbidden_headers+=("${header_path#"$REPO_ROOT/"}")
done < <(find "$REPO_ROOT/Sources/SentryCrashV9Headers/include" -type f \
  \( -name '*.h' -o -name '*.hpp' \) -print | sort)
while IFS= read -r header_path; do
  forbidden_headers+=("${header_path#"$REPO_ROOT/"}")
done < <(find "$REPO_ROOT/Sources/SentryCrash" -type f \
  \( -name '*.h' -o -name '*.hpp' \) -print | sort)

violation_count=0
record_error() {
  log_error "$1"
  violation_count=$((violation_count + 1))
}

# Native SwiftPM describes the entire package, including unrequested targets. Validate the actual
# requested command closure before taking its associated plans/descriptions/maps out of the raw
# scan. All other metadata (including Xcode/SwiftBuild output) and actual dependencies stay checked.
source_patterns=$(mktemp)
header_patterns=$(mktemp)
metadata_paths=$(mktemp)
dependency_paths=$(mktemp)
native_metadata_paths=$(mktemp)
trap 'rm -f "$source_patterns" "$header_patterns" "$metadata_paths" "$dependency_paths" "$native_metadata_paths"' EXIT
printf '%s\n' "${forbidden_sources[@]}" > "$source_patterns"
printf '%s\n' "${forbidden_headers[@]}" > "$header_patterns"
find "$BUILD_PATH" -type f \
  \( -name '*.scan' -o -name '*.d' -o -name '*.json' -o -name '*.yaml' -o -name '*.txt' \
  -o -name '*.rsp' -o -name '*.SwiftFileList' -o -name '*.LinkFileList' \) \
  -print0 > "$metadata_paths"
find "$BUILD_PATH" -type f \( -name '*.scan' -o -name '*.d' \) -print0 > "$dependency_paths"

if [[ -f "$BUILD_PATH/debug.yaml" || -f "$BUILD_PATH/release.yaml" || -f "$BUILD_PATH/plugin-tools.yaml" ]]; then
  if "$SCRIPT_DIR/verify-v10-spm-build-plan.swift" \
    --build-path "$BUILD_PATH" --source-patterns "$source_patterns" \
    --metadata-paths "$metadata_paths" --remaining-metadata-paths "$native_metadata_paths" \
    ${SPM_TARGETS[@]+"${SPM_TARGETS[@]}"}; then
    mv "$native_metadata_paths" "$metadata_paths"
  else
    record_error "Could not verify the requested native SwiftPM build"
  fi
fi

metadata_matches=""
if [[ -s "$metadata_paths" ]]; then
  metadata_matches=$(xargs -0 grep -aIlFf "$source_patterns" < "$metadata_paths" || true)
fi
if [[ -n "$metadata_matches" ]]; then
  record_error "V10 build metadata schedules a V9 recorder or adapter implementation"
  printf '%s\n' "$metadata_matches"
fi

dependency_matches=""
if [[ -s "$dependency_paths" ]]; then
  dependency_matches=$(xargs -0 grep -aIlFf "$header_patterns" < "$dependency_paths" || true)
fi
if [[ -n "$dependency_matches" ]]; then
  record_error "V10 dependency metadata resolves a V9 recorder header"
  printf '%s\n' "$dependency_matches"
fi

# Object basenames are an independent fallback for Xcode output directories that omit compile
# metadata. The denylist is exact and gathered from the source, so historically named SDK-owned
# objects are not rejected.
while IFS= read -r -d '' object_path; do
  object_name=$(basename "$object_path")
  for source_path in "${forbidden_sources[@]}"; do
    source_name=$(basename "$source_path")
    source_stem=${source_name%.*}
    if [[ "$object_name" == "$source_stem.o" || "$object_name" == "$source_name.o" ]]; then
      record_error "V10 emitted an object reserved for $source_path: $object_path"
      break
    fi
  done
done < <(find "$BUILD_PATH" -type f -name '*.o' -print0)

if [[ $violation_count -ne 0 ]]; then
  log_error "$violation_count V10 SentryCrash compile/object violation(s) found"
  exit 1
fi

log_info "Verified no V9 recorder or adapter compile command or object is present"
