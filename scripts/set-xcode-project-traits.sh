#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

TRAIT=""
MODE=""

usage() {
    log_notice "Usage: $0"
    log_notice "  -t, --trait <name>      Package trait to set or clear (required)"
    log_notice "  -m, --mode <add|remove> Whether to add or remove the trait (required)"
    log_notice ""
    log_notice "Patches all XcodeGen-generated .xcodeproj files under Samples/ to add or"
    log_notice "remove a Swift package trait on every XCLocalSwiftPackageReference entry."
    log_notice ""
    log_notice "Example: $0 --trait V10 --mode add"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--trait) TRAIT="$2"; shift 2 ;;
        -m|--mode) MODE="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$TRAIT" ]; then
    log_error "Error: --trait is required"
    usage
fi

if [ -z "$MODE" ]; then
    log_error "Error: --mode is required"
    usage
fi

if [ "$MODE" != "add" ] && [ "$MODE" != "remove" ]; then
    log_error "Error: --mode must be 'add' or 'remove'"
    usage
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PBXPROJ_FILES=()
while IFS= read -r -d '' f; do
    PBXPROJ_FILES+=("$f")
done < <(find "$REPO_ROOT/Samples" -name "project.pbxproj" -not -path "*/.build/*" -print0)

if [ ${#PBXPROJ_FILES[@]} -eq 0 ]; then
    log_warning "No project.pbxproj files found under Samples/ — run 'make xcode-ci' first"
    exit 0
fi

for PBXPROJ in "${PBXPROJ_FILES[@]}"; do
    PROJECT="$(basename "$(dirname "$(dirname "$PBXPROJ")")")"
    begin_group "$MODE trait '$TRAIT' in $PROJECT"

    python3 - "$PBXPROJ" "$TRAIT" "$MODE" <<'PYEOF'
import sys, re

pbxproj_path, trait, mode = sys.argv[1], sys.argv[2], sys.argv[3]

with open(pbxproj_path) as f:
    content = f.read()

# Match each XCLocalSwiftPackageReference block: from `{` to `};`
# We operate on the full block so we can add/remove traits cleanly.
def patch_block(m):
    block = m.group(0)

    if mode == "add":
        if f"\t\t\ttraits = (" in block:
            # traits block exists — add trait if not already there
            if f"\t\t\t\t{trait}," in block:
                return block  # already present
            return block.replace(
                "\t\t\ttraits = (\n",
                f"\t\t\ttraits = (\n\t\t\t\t{trait},\n"
            )
        else:
            # No traits block — insert one before the closing `};`
            return block.replace(
                "\t\t};\n",
                f"\t\t\ttraits = (\n\t\t\t\t{trait},\n\t\t\t);\n\t\t}};\n"
            )
    else:  # remove
        # Remove the trait line
        block = re.sub(rf"\t\t\t\t{re.escape(trait)},\n", "", block)
        # Remove empty traits block
        block = re.sub(r"\t\t\ttraits = \(\n\t\t\t\);\n", "", block)
        return block

# Match each XCLocalSwiftPackageReference object block
pattern = re.compile(
    r'\t\t\w+ /\* XCLocalSwiftPackageReference "[^"]*" \*/ = \{[^}]+\};\n',
    re.DOTALL
)

new_content = pattern.sub(patch_block, content)

if new_content != content:
    with open(pbxproj_path, "w") as f:
        f.write(new_content)
    print(f"  Updated '{pbxproj_path}'")
else:
    print(f"  No change needed")
PYEOF

    end_group
done

ACTION="$([ "$MODE" = "add" ] && echo "added" || echo "removed")"
log_info "Done: trait '$TRAIT' $ACTION in ${#PBXPROJ_FILES[@]} project(s)"
