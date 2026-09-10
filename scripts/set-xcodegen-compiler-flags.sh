#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

SPEC=""
SWIFT_CONDITIONS=()
C_DEFINES=()

usage() {
    log_notice "Usage: $(basename "$0")"
    log_notice "  -s, --spec <path>              XcodeGen YAML spec (required)"
    log_notice "  -S, --swift-condition <name>   SWIFT_ACTIVE_COMPILATION_CONDITIONS flag"
    log_notice "                                 (repeatable)"
    log_notice "  -D, --c-define <name[=value]>  GCC_PREPROCESSOR_DEFINITIONS flag"
    log_notice "                                 (repeatable)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--spec)             SPEC="$2";                shift 2 ;;
        -S|--swift-condition)  SWIFT_CONDITIONS+=("$2"); shift 2 ;;
        -D|--c-define)         C_DEFINES+=("$2");        shift 2 ;;
        *)                     usage ;;
    esac
done

if [[ -z "$SPEC" ]]; then
    log_error "--spec is required"
    usage
fi

if [[ ${#SWIFT_CONDITIONS[@]} -eq 0 && ${#C_DEFINES[@]} -eq 0 ]]; then
    log_error "--swift-condition or --c-define is required"
    usage
fi

if [[ ! -f "$SPEC" ]]; then
    log_error "Spec not found: $SPEC"
    exit 1
fi

for flag in "${SWIFT_CONDITIONS[@]}"; do
    if [[ ! "$flag" =~ ^[A-Za-z0-9_]+$ ]]; then
        log_error "Invalid Swift condition '$flag'"
        exit 1
    fi
done

for flag in "${C_DEFINES[@]}"; do
    if [[ ! "$flag" =~ ^[A-Za-z0-9_.=]+$ ]]; then
        log_error "Invalid C define '$flag'"
        exit 1
    fi
done

if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required (brew install yq)"
    exit 1
fi

# $(inherited) must stay literal for Xcode; do not let the shell expand it.
# shellcheck disable=SC2016
inherited='$(inherited)'

if [[ ${#SWIFT_CONDITIONS[@]} -gt 0 ]]; then
    SWIFT_VALUE="$inherited"
    for flag in "${SWIFT_CONDITIONS[@]}"; do
        SWIFT_VALUE+=" $flag"
    done
    SWIFT_VALUE="$SWIFT_VALUE" yq -i \
        '.targets[] |= (.settings.base.SWIFT_ACTIVE_COMPILATION_CONDITIONS = strenv(SWIFT_VALUE))' \
        "$SPEC"
fi

if [[ ${#C_DEFINES[@]} -gt 0 ]]; then
    C_VALUE="$inherited"
    for flag in "${C_DEFINES[@]}"; do
        C_VALUE+=" $flag"
    done
    C_VALUE="$C_VALUE" yq -i \
        '.targets[] |= (.settings.base.GCC_PREPROCESSOR_DEFINITIONS = strenv(C_VALUE))' \
        "$SPEC"
fi
