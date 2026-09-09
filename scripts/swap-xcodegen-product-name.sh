#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

SPEC=""
PRODUCT=""
WITH=""

usage() {
    log_notice "Usage: $(basename "$0")"
    log_notice "  -s, --spec <path>        XcodeGen YAML spec (required)"
    log_notice "  -p, --product <name>     Product name to replace (required)"
    log_notice "  -w, --with <name>        Replacement product name (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--spec)    SPEC="$2";    shift 2 ;;
        -p|--product) PRODUCT="$2"; shift 2 ;;
        -w|--with)    WITH="$2";    shift 2 ;;
        *)            usage ;;
    esac
done

if [[ -z "$SPEC" ]]; then
    log_error "--spec is required"
    usage
fi

if [[ -z "$PRODUCT" ]]; then
    log_error "--product is required"
    usage
fi

if [[ -z "$WITH" ]]; then
    log_error "--with is required"
    usage
fi

if [[ ! -f "$SPEC" ]]; then
    log_error "Spec not found: $SPEC"
    exit 1
fi

if [[ ! "$PRODUCT" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    log_error "Invalid product name '$PRODUCT'"
    exit 1
fi

if [[ ! "$WITH" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    log_error "Invalid product name '$WITH'"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required (brew install yq)"
    exit 1
fi

# Rewrite both XcodeGen forms:
#   product: <name>
#   products: [<name>, ...]
FROM="$PRODUCT" TO="$WITH" yq -i '
    (.targets[].dependencies[] | select(.product == strenv(FROM))).product = strenv(TO) |
    (.targets[].dependencies[] | select(has("products")).products[] | select(. == strenv(FROM))) = strenv(TO)
' "$SPEC"
