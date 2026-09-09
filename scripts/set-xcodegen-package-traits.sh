#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

SPEC=""
TRAITS=()

usage() {
    log_notice "Usage: $(basename "$0")"
    log_notice "  -s, --spec <path>     XcodeGen YAML spec (required)"
    log_notice "  -t, --trait <name>    Package trait to set on local path packages"
    log_notice "                        (repeatable, required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--spec)  SPEC="$2";      shift 2 ;;
        -t|--trait) TRAITS+=("$2"); shift 2 ;;
        *)          usage ;;
    esac
done

if [[ -z "$SPEC" ]]; then
    log_error "--spec is required"
    usage
fi

if [[ ${#TRAITS[@]} -eq 0 ]]; then
    log_error "--trait is required"
    usage
fi

if [[ ! -f "$SPEC" ]]; then
    log_error "Spec not found: $SPEC"
    exit 1
fi

for trait in "${TRAITS[@]}"; do
    if [[ ! "$trait" =~ ^[A-Za-z0-9_]+$ ]]; then
        log_error "Invalid trait name '$trait'"
        exit 1
    fi
done

if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required (brew install yq)"
    exit 1
fi

for trait in "${TRAITS[@]}"; do
    TRAIT="$trait" yq -i \
        '(.packages[] | select(has("path"))).traits |= ((. // []) + [strenv(TRAIT)] | unique)' \
        "$SPEC"
done
