#!/bin/bash
set -euo pipefail

# Static linkers pull archive members in to satisfy symbol references. Category
# methods alone may not cause their object file to be loaded without flags such
# as -ObjC, leaving those methods unavailable at runtime. Require category metadata
# to share an object file with an ObjC class or Swift type definition instead.
# This is a layout policy, not a reachability proof: consumers must still reference
# the co-located type for it to serve as a reason to load that archive member.

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

log_info "Validating Objective-C category layout: $XCFRAMEWORK_PATH"
info_plist_path="$XCFRAMEWORK_PATH/Info.plist"
if [ ! -f "$info_plist_path" ]; then
    log_error "Missing XCFramework Info.plist: $info_plist_path"
    exit 1
fi

# Use the bundle manifest rather than assuming platform directory names or that
# every library is packaged as a .framework instead of a standalone archive.
log_info "Reading library entries from $info_plist_path"
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

    log_info "$library_identifier: inspecting $binary_path"

    # Universal binaries can have different member layouts in each architecture.
    # Inspect each slice independently, including its static/dynamic binary type.
    archs="$(xcrun lipo -archs "$binary_path")"
    log_info "$library_identifier: found architectures: $archs"
    read -ra arch_array <<< "$archs"
    for arch in "${arch_array[@]}"; do
        archive_path="$WORK_DIR/library.a"
        if [ "${#arch_array[@]}" -gt 1 ]; then
            log_info "$library_identifier ($arch): extracting architecture for inspection"
            xcrun lipo "$binary_path" -thin "$arch" -output "$archive_path"
        else
            log_info "$library_identifier ($arch): copying single-architecture binary for inspection"
            cp "$binary_path" "$archive_path"
        fi

        binary_type="$(file -b "$archive_path")"
        case "$binary_type" in
            *"current ar archive"*)
                ;;
            *"dynamically linked shared library"*)
                # Dynamic libraries do not undergo the consumer-side archive-member
                # selection that this policy is intended to guard against.
                log_notice "$library_identifier ($arch): dynamic library, skipping archive-member check"
                continue
                ;;
            *)
                log_error "$library_identifier ($arch): unsupported binary format: $binary_type"
                exit 1
                ;;
        esac
        checked_archives=$((checked_archives + 1))
        log_info "$library_identifier ($arch): scanning static archive member metadata"

        # Read members directly so duplicate object filenames cannot overwrite each other
        # during extraction. Inspect metadata sections rather than symbols: type
        # references and incidental compiler-generated helpers do not establish
        # that the member defines a class or Swift type.
        xcrun otool -l "$archive_path" > "$WORK_DIR/load-commands.txt"
        if ! awk -v archive="$archive_path" '
            function report_member() {
                if (has_category && !has_type) print member
            }

            # Each archive(member): header starts a new object. A type in a different
            # member cannot cause this category-bearing member to be loaded.
            index($0, archive "(") == 1 && substr($0, length($0) - 1) == "):" {
                report_member()
                member = substr($0, length(archive) + 2, length($0) - length(archive) - 3)
                member_count++
                has_category = 0
                has_type = 0
                section = ""
            }
            $1 == "sectname" { section = $2 }

            # Empty sections carry no metadata. Cover both regular and non-lazy
            # category lists, and accept only class/type definition lists as anchors.
            $1 == "size" && $2 !~ /^0x0+$/ {
                if (section == "__objc_catlist" || section == "__objc_nlcatlist") has_category = 1
                if (section == "__objc_classlist" || section == "__swift5_types") has_type = 1
            }

            END {
                # The final member has no following header to trigger its report.
                report_member()
                # Fail closed if no member headers were recognized, rather than
                # treating unreadable or unexpected tool output as a clean archive.
                if (member_count == 0) exit 1
            }
        ' "$WORK_DIR/load-commands.txt" > "$WORK_DIR/violations.txt"; then
            log_error "$library_identifier ($arch): could not read archive members"
            exit 1
        fi

        # Collect all layout violations so one run identifies affected members
        # across every slice. Tool/format errors above abort immediately instead.
        errors_before_archive="$validation_errors"
        while IFS= read -r member; do
            log_error "$library_identifier ($arch): $member contains category metadata without a type definition"
            validation_errors=$((validation_errors + 1))
        done < "$WORK_DIR/violations.txt"
        log_info "$library_identifier ($arch): scan complete, $((validation_errors - errors_before_archive)) category-only member(s)"
    done
done <<< "$library_records"

if [ "$processed_libraries" -eq 0 ]; then
    log_error "XCFramework Info.plist does not contain any AvailableLibraries entries"
    exit 1
fi
log_info "Inspected $processed_libraries library entry/entries and checked $checked_archives static architecture(s)"
if [ "$validation_errors" -ne 0 ]; then
    log_error "ObjC category validation found $validation_errors category-only member(s) across $checked_archives architecture(s). Co-locate categories with an intentionally referenced SDK type."
    exit 1
fi
log_notice "ObjC category validation passed for $checked_archives static architecture(s)."
