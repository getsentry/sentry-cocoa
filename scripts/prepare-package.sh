#!/usr/bin/env bash

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Prepare Package.swift files for CI builds.

OPTIONS:
    --package-file PATH              Single Package.swift file (default: all discovered)
    -h, --help                       Show this help message

DEPRECATED (accepted but ignored — binary targets moved to distribution repo):
    --is-pr, --remove-duplicate, --change-path,
    --remove-binary-targets, --strip-binary-targets

EXAMPLES:
    $(basename "$0") --package-file Package.swift

EOF
    exit 1
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-file)
      [[ $# -lt 2 ]] && { log_error "Missing value for $1"; exit 1; }
      PACKAGE_FILES=("$2")
      shift 2
      ;;
    --is-pr|--remove-duplicate|--change-path|--remove-binary-targets|--strip-binary-targets)
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

log_info "Preparing package files:"
log_info "  Files: ${PACKAGE_FILES[*]}"

for PACKAGE_FILE in "${PACKAGE_FILES[@]}"; do
  begin_group "$PACKAGE_FILE (after prepare-package.sh)"
  cat "$PACKAGE_FILE"
  end_group
done
