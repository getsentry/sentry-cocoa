#!/bin/bash
set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

TRAIT=""
MODE=""
SPEC=""
GENERATE=false

# Binary XCFramework samples cannot enable V10. macOS-CLI-Xcode uses the
# NoUIFramework trait and must not pick up V10 from a bulk generate.
SKIP_SPECS=(
    "macOS-CLI-Xcode.yml"
    "iOS-ObjectiveC-Dynamic.yml"
    "iOS-ObjectiveC-Static.yml"
)

usage() {
    log_notice "Usage: $(basename "$0")"
    log_notice "  -t, --trait <name>      Package trait to add or remove (required)"
    log_notice "  -m, --mode <add|remove> Add or remove the trait on YAML specs"
    log_notice "  -s, --spec <path>       XcodeGen YAML spec (all Samples/ specs when omitted)"
    log_notice "  -g, --generate          Copy each spec, add the trait, run xcodegen,"
    log_notice "                          then delete the copy so committed YAML is unchanged"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--trait)     TRAIT="$2";     shift 2 ;;
        -m|--mode)      MODE="$2";      shift 2 ;;
        -s|--spec)      SPEC="$2";      shift 2 ;;
        -g|--generate)  GENERATE=true;  shift ;;
        *)              usage ;;
    esac
done

if [[ -z "$TRAIT" ]]; then
    log_error "--trait is required"
    usage
fi

if [[ ! "$TRAIT" =~ ^[A-Za-z0-9_]+$ ]]; then
    log_error "Invalid trait name '$TRAIT'"
    exit 1
fi

if $GENERATE; then
    MODE="add"
fi

if [[ -z "$MODE" ]]; then
    log_error "--mode is required unless --generate is set"
    usage
fi

if [[ "$MODE" != "add" && "$MODE" != "remove" ]]; then
    log_error "--mode must be 'add' or 'remove'"
    usage
fi

if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required (brew install yq)"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="$REPO_ROOT/Samples"

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

add_trait() {
    yq -i \
        "(.packages[] | select(has(\"path\"))).traits |= ((. // []) + [\"${TRAIT}\"] | unique)" \
        "$1"
}

remove_trait() {
    yq -i \
        "(.packages[] | select(has(\"path\"))).traits |= ((. // []) - [\"${TRAIT}\"]) | del(.packages[].traits | select(length == 0))" \
        "$1"
}

patch_spec() {
    if [[ "$MODE" == "add" ]]; then
        add_trait "$1"
    else
        remove_trait "$1"
    fi
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
    SPECS=()
    if [[ -n "$SPEC" ]]; then
        SPECS=("$(resolve_spec "$SPEC")")
        return 0
    fi
    while IFS= read -r -d '' spec; do
        SPECS+=("$spec")
    done < <(collect_specs)
}

generate_from_spec() {
    local spec="$1"
    local dir base tmp
    dir="$(dirname "$spec")"
    base="$(basename "$spec" .yml)"
    tmp="$dir/${base}.v10.yml"

    rm -f "$tmp"
    trap 'rm -f "'"$tmp"'"' EXIT
    cp "$spec" "$tmp"
    add_trait "$tmp"
    begin_group "generate with trait '$TRAIT': $spec"
    xcodegen --spec "$tmp"
    log_info "  Generated"
    end_group
    rm -f "$tmp"
    trap - EXIT
}

gather_specs

if [[ ${#SPECS[@]} -eq 0 ]]; then
    log_warning "No XcodeGen specs with local packages found under Samples/"
    exit 0
fi

if $GENERATE; then
    local_spec=""
    for local_spec in "${SPECS[@]}"; do
        generate_from_spec "$local_spec"
    done
    log_info "Done: generated ${#SPECS[@]} project(s) with trait '$TRAIT'"
    exit 0
fi

for spec in "${SPECS[@]}"; do
    begin_group "$MODE trait '$TRAIT' in $(basename "$(dirname "$spec")")"
    patch_spec "$spec"
    log_info "  Updated $spec"
    end_group
done

action="added"
if [[ "$MODE" == "remove" ]]; then
    action="removed"
fi
log_info "Done: trait '$TRAIT' $action in ${#SPECS[@]} spec(s)"
