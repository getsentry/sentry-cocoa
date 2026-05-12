#!/bin/bash

set -e

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <xcframework_path>

Validate the structure and symlinks of an XCFramework bundle.

Checks each platform slice for correct framework layout, valid symlinks,
and proper Versions directory structure (macOS frameworks).

ARGUMENTS:
    xcframework_path    Path to the .xcframework directory

EXAMPLES:
    $(basename "$0") Sentry-Dynamic.xcframework
    $(basename "$0") SentrySwiftUI.xcframework

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [ $# -ne 1 ]; then
    log_error "Expected 1 argument (xcframework_path), got $#"
    usage
fi

XCFRAMEWORK_PATH="$1"

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    log_error "XCFramework path does not exist: $XCFRAMEWORK_PATH"
    exit 1
fi

if [ ! -f "$XCFRAMEWORK_PATH/Info.plist" ]; then
    log_error "$XCFRAMEWORK_PATH is not a valid XCFramework (missing Info.plist)"
    exit 1
fi

log_info "Validating XCFramework: $XCFRAMEWORK_PATH"

# Track validation results
validation_errors=0

# Function to check if a path is a symlink
is_symlink() {
    [ -L "$1" ]
}

# Function to check if a symlink is valid (points to existing target)
is_valid_symlink() {
    if is_symlink "$1"; then
        target=$(readlink "$1")
        [ -e "$(dirname "$1")/$target" ]
    else
        false
    fi
}

# Function to validate framework structure
validate_framework() {
    local framework_path="$1"
    local framework_name
    framework_name=$(basename "$framework_path" .framework)
    local binary_path="$framework_path/$framework_name"
    
    log_info "  Validating framework: $framework_name"
    
    # Check if framework has a Versions directory
    if [ -d "$framework_path/Versions" ]; then
        log_info "    Framework is versioned"
        
        # Check if the main binary is a symlink
        if is_symlink "$binary_path"; then
            log_info "    Main binary is a symlink"

            # Check if the symlink is valid
            if is_valid_symlink "$binary_path"; then
                log_info "    Symlink is valid"

                # Get the target of the symlink
                symlink_target=$(readlink "$binary_path")
                log_info "    Symlink points to: $symlink_target"

                # Verify the target exists in Versions
                if [ -f "$framework_path/$symlink_target" ]; then
                    log_info "    Symlink target exists"
                else
                    log_error "Symlink target does not exist: $framework_path/$symlink_target"
                    validation_errors=$((validation_errors + 1))
                fi
            else
                log_error "Symlink is broken (target does not exist)"
                validation_errors=$((validation_errors + 1))
            fi
        else
            log_error "Main binary should be a symlink when Versions directory exists"
            validation_errors=$((validation_errors + 1))
        fi
        
        # Check Versions directory structure
        if [ -d "$framework_path/Versions/Current" ]; then
            log_info "    Found Versions/Current directory"
            
            # Check if Current is a symlink
            if is_symlink "$framework_path/Versions/Current"; then
                log_info "    Versions/Current is a symlink"

                if is_valid_symlink "$framework_path/Versions/Current"; then
                    log_info "    Versions/Current symlink is valid"
                else
                    log_error "Versions/Current symlink is broken"
                    validation_errors=$((validation_errors + 1))
                fi
            else
                log_error "Versions/Current should be a symlink"
                validation_errors=$((validation_errors + 1))
            fi
        else
            log_error "Versions/Current directory not found"
            validation_errors=$((validation_errors + 1))
        fi
    else
        log_info "    No Versions directory found (standard framework structure)"
        
        # For frameworks without Versions, the binary should be a regular file
        if [ -f "$binary_path" ] && ! is_symlink "$binary_path"; then
            log_info "    Main binary is not a symlink"
        else
            log_error "Main binary is a symlink or does not exist: $binary_path"
            validation_errors=$((validation_errors + 1))
        fi
    fi
}

begin_group "Discovering platform slices"
platform_dirs=$(find "$XCFRAMEWORK_PATH" -maxdepth 1 -type d -not -name "*.xcframework" -not -name "." | grep -v "Info.plist" | sort)

if [ -z "$platform_dirs" ]; then
    log_error "No platform directories found in $XCFRAMEWORK_PATH"
    exit 1
fi

platform_count=0
while IFS= read -r dir; do
    [ -n "$dir" ] && platform_count=$((platform_count + 1))
done <<< "$platform_dirs"

log_info "Found $platform_count platform slice(s):"
while IFS= read -r dir; do
    [ -n "$dir" ] && log_info "  $(basename "$dir")"
done <<< "$platform_dirs"
end_group

framework_count=0

while IFS= read -r platform_dir; do
    if [ -n "$platform_dir" ]; then
        platform_name=$(basename "$platform_dir")
        begin_group "Validate: $platform_name"

        frameworks=$(find "$platform_dir" -name "*.framework" -type d)

        if [ -z "$frameworks" ]; then
            log_warning "No .framework directories found in $platform_name"
        else
            while IFS= read -r framework; do
                if [ -n "$framework" ]; then
                    validate_framework "$framework"
                    framework_count=$((framework_count + 1))
                fi
            done <<< "$frameworks"
        fi

        end_group
    fi
done <<< "$platform_dirs"

log_info "Validation summary:"
log_info "  XCFramework:      $XCFRAMEWORK_PATH"
log_info "  Platform slices:   $platform_count"
log_info "  Frameworks checked: $framework_count"
log_info "  Errors:            $validation_errors"

if [ $validation_errors -eq 0 ]; then
    log_info "Validation passed"
    exit 0
else
    log_error "Validation failed for $XCFRAMEWORK_PATH with $validation_errors error(s)"
    exit 1
fi
