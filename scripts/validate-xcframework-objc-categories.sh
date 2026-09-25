#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

XCFRAMEWORK_PATH=""
validation_errors=0
processed_libraries=0
checked_archives=0

usage() {
    log_notice "Usage: $0 --xcframework <path>"
    log_notice "  -x, --xcframework <path>    XCFramework bundle to validate (required)"
    log_notice "  -h, --help                  Show this help"
    log_notice "Reject static archive members containing ObjC categories without an ObjC class or Swift type definition."
    log_notice "This structural check does not prove that the co-located type is linked by every consumer."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--xcframework)
            if [ $# -lt 2 ]; then
                usage
                exit 1
            fi
            XCFRAMEWORK_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$XCFRAMEWORK_PATH" ]; then
    log_error "Error: --xcframework is required"
    usage
    exit 1
fi

info_plist_path="$XCFRAMEWORK_PATH/Info.plist"
if [ ! -f "$info_plist_path" ]; then
    log_error "Missing XCFramework Info.plist: $info_plist_path"
    exit 1
fi

library_records="$(plutil -convert json -o - "$info_plist_path" \
    | jq -r '.AvailableLibraries[] | [.LibraryIdentifier, .LibraryPath] | @tsv')"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sentry-objc-categories.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while IFS=$'\t' read -r library_identifier library_path; do
    if [ -z "$library_identifier" ]; then
        continue
    fi
    processed_libraries=$((processed_libraries + 1))
    binary_path="$XCFRAMEWORK_PATH/$library_identifier/$library_path"
    if [[ "$library_path" == *.framework ]]; then
        binary_path="$binary_path/$(basename "$library_path" .framework)"
    fi
    if [ ! -f "$binary_path" ]; then
        log_error "Missing library binary: $binary_path"
        exit 1
    fi

    archs="$(xcrun lipo -archs "$binary_path")"
    read -ra arch_array <<< "$archs"
    for arch in "${arch_array[@]}"; do
        archive_path="$WORK_DIR/library.a"
        if [ "${#arch_array[@]}" -gt 1 ]; then
            xcrun lipo "$binary_path" -thin "$arch" -output "$archive_path"
        else
            cp "$binary_path" "$archive_path"
        fi

        binary_type="$(file -b "$archive_path")"
        case "$binary_type" in
            *"current ar archive"*)
                ;;
            *"dynamically linked shared library"*)
                log_notice "$library_identifier ($arch): dynamic library, skipping archive-member check"
                continue
                ;;
            *)
                log_error "$library_identifier ($arch): unsupported binary format: $binary_type"
                exit 1
                ;;
        esac
        checked_archives=$((checked_archives + 1))

        # Read members directly so duplicate object filenames cannot overwrite each other
        # during extraction. Type references and incidental generic helpers are not anchors.
        xcrun otool -l "$archive_path" > "$WORK_DIR/load-commands.txt"
        if ! awk -v archive="$archive_path" '
            function report_member() {
                if (has_category && !has_type) print member
            }
            index($0, archive "(") == 1 && substr($0, length($0) - 1) == "):" {
                report_member()
                member = substr($0, length(archive) + 2, length($0) - length(archive) - 3)
                member_count++
                has_category = 0
                has_type = 0
                section = ""
            }
            $1 == "sectname" { section = $2 }
            $1 == "size" && $2 !~ /^0x0+$/ {
                if (section == "__objc_catlist" || section == "__objc_nlcatlist") has_category = 1
                if (section == "__objc_classlist" || section == "__swift5_types") has_type = 1
            }
            END {
                report_member()
                if (member_count == 0) exit 1
            }
        ' "$WORK_DIR/load-commands.txt" > "$WORK_DIR/violations.txt"; then
            log_error "$library_identifier ($arch): could not read archive members"
            exit 1
        fi

        while IFS= read -r member; do
            log_error "$library_identifier ($arch): $member contains category metadata without a type definition"
            validation_errors=$((validation_errors + 1))
        done < "$WORK_DIR/violations.txt"
    done
done <<< "$library_records"

if [ "$processed_libraries" -eq 0 ]; then
    log_error "XCFramework Info.plist does not contain any AvailableLibraries entries"
    exit 1
fi
if [ "$validation_errors" -ne 0 ]; then
    log_error "ObjC category validation found $validation_errors category-only member(s) across $checked_archives architecture(s). Co-locate categories with an intentionally referenced SDK type."
    exit 1
fi
log_notice "ObjC category validation passed for $checked_archives static architecture(s)."
