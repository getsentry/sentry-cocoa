#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SAMPLES_DIR="$REPO_ROOT/Samples"

SPECS=()
PRODUCT=""
WITH=""

# Binary XCFramework samples cannot enable V10. macOS-CLI-Xcode uses the
# NoUIFramework trait and must not pick up V10 from a bulk generate.
SKIP_SPECS=(
    "macOS-CLI-Xcode.yml"
    "iOS-ObjectiveC-Dynamic.yml"
    "iOS-ObjectiveC-Static.yml"
)

usage() {
    log_notice "Usage: $(basename "$0")"
    log_notice "  -s, --spec <path>        XcodeGen YAML spec (repeatable; all eligible"
    log_notice "                           Samples/ specs when omitted)"
    log_notice "  -p, --product <name>     Product name to replace in the generate copy"
    log_notice "  -w, --with <name>        Replacement product name (required with --product)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--spec)    SPECS+=("$2"); shift 2 ;;
        -p|--product) PRODUCT="$2";  shift 2 ;;
        -w|--with)    WITH="$2";     shift 2 ;;
        *)            usage ;;
    esac
done

if [[ -n "$PRODUCT" && -z "$WITH" ]]; then
    log_error "--with is required when --product is set"
    usage
fi

if [[ -z "$PRODUCT" && -n "$WITH" ]]; then
    log_error "--product is required when --with is set"
    usage
fi

if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required (brew install yq)"
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    log_error "xcodegen is required"
    exit 1
fi

should_skip() {
    local basename
    basename="$(basename "$1")"
    local skip
    for skip in "${SKIP_SPECS[@]}"; do
        if [[ "$basename" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

has_local_packages() {
    yq -e '.packages | to_entries | map(select(.value | has("path"))) | length > 0' "$1" >/dev/null 2>&1
}

resolve_spec() {
    local spec="$1"
    if [[ -f "$spec" ]]; then
        echo "$spec"
        return 0
    fi
    if [[ -f "$REPO_ROOT/$spec" ]]; then
        echo "$REPO_ROOT/$spec"
        return 0
    fi
    log_error "Spec not found: $spec"
    return 1
}

collect_specs() {
    local spec
    while IFS= read -r -d '' spec; do
        if should_skip "$spec"; then
            continue
        fi
        if ! has_local_packages "$spec"; then
            continue
        fi
        printf '%s\0' "$spec"
    done < <(find "$SAMPLES_DIR" -name '*.yml' ! -path '*/Shared/*' -print0)
}

gather_specs() {
    local resolved=()
    local spec
    if [[ ${#SPECS[@]} -gt 0 ]]; then
        for spec in "${SPECS[@]}"; do
            resolved+=("$(resolve_spec "$spec")")
        done
        SPECS=("${resolved[@]}")
        return 0
    fi
    SPECS=()
    while IFS= read -r -d '' spec; do
        SPECS+=("$spec")
    done < <(collect_specs)
}

patch_and_generate() {
    local spec="$1"
    local dir base tmp
    dir="$(dirname "$spec")"
    base="$(basename "$spec" .yml)"
    tmp="$dir/${base}.v10.yml"

    (
        trap 'rm -f "$tmp"' EXIT
        cp "$spec" "$tmp"
        "$SCRIPT_DIR/set-xcodegen-package-traits.sh" --spec "$tmp" --trait V10
        "$SCRIPT_DIR/set-xcodegen-compiler-flags.sh" \
            --spec "$tmp" \
            --swift-condition SDK_V10 \
            --c-define SDK_V10=1
        if [[ -n "$PRODUCT" ]]; then
            "$SCRIPT_DIR/swap-xcodegen-product-name.sh" \
                --spec "$tmp" \
                --product "$PRODUCT" \
                --with "$WITH"
        fi
        begin_group "generate V10: $spec"
        xcodegen --spec "$tmp"
        log_info "  Generated"
        end_group
    )
}

gather_specs

if [[ ${#SPECS[@]} -eq 0 ]]; then
    log_warning "No XcodeGen specs with local packages found under Samples/"
    exit 0
fi

for spec in "${SPECS[@]}"; do
    patch_and_generate "$spec"
done

log_info "Done: generated ${#SPECS[@]} V10 project(s)"
if [[ -n "$PRODUCT" ]]; then
    log_notice "Product refs rewritten from '$PRODUCT' to '$WITH'. Open Xcode with SDK_V10=1."
fi
