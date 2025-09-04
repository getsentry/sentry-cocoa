#!/bin/bash

# Script to validate the format of XCFramework bundles
# Usage: ./scripts/validate-xcframework-format.sh <xcframework_path>
# Example: ./scripts/validate-xcframework-format.sh Sentry.xcframework

set -e

# Check if required arguments are provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <xcframework_path>"
    echo "Example: $0 Sentry.xcframework"
    exit 1
fi

XCFRAMEWORK_PATH="$1"

# Validate that the xcframework path exists
if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo "Error: XCFramework path does not exist: $XCFRAMEWORK_PATH"
    exit 1
fi

# Check if it's actually an xcframework
if [ ! -f "$XCFRAMEWORK_PATH/Info.plist" ]; then
    echo "Error: $XCFRAMEWORK_PATH is not a valid XCFramework (missing Info.plist)"
    exit 1
fi

echo "Validating XCFramework format: $XCFRAMEWORK_PATH"

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
    
    echo "  Validating framework: $framework_name"
    
    # Check if framework has a Versions directory
    if [ -d "$framework_path/Versions" ]; then
        echo "    Framework is versioned"
        
        # Check if the main binary is a symlink
        if is_symlink "$binary_path"; then
            echo "    ✅ Main binary is a symlink"
            
            # Check if the symlink is valid
            if is_valid_symlink "$binary_path"; then
                echo "    ✅ Symlink is valid"
                
                # Get the target of the symlink
                symlink_target=$(readlink "$binary_path")
                echo "    ✅ Symlink points to: $symlink_target"
                
                # Verify the target exists in Versions
                if [ -f "$framework_path/$symlink_target" ]; then
                    echo "    ✅ Symlink target exists"
                else
                    echo "    ❌ Symlink target does not exist: $framework_path/$symlink_target"
                    ((validation_errors++))
                fi
            else
                echo "    ❌ Symlink is broken (target does not exist)"
                ((validation_errors++))
            fi
        else
            echo "    ❌ Main binary should be a symlink when Versions directory exists"
            ((validation_errors++))
        fi
        
        # Check Versions directory structure
        if [ -d "$framework_path/Versions/Current" ]; then
            echo "    Found Versions/Current directory"
            
            # Check if Current is a symlink
            if is_symlink "$framework_path/Versions/Current"; then
                echo "    ✅ Versions/Current is a symlink"
                
                if is_valid_symlink "$framework_path/Versions/Current"; then
                    echo "    ✅ Versions/Current symlink is valid"
                else
                    echo "    ❌ Versions/Current symlink is broken"
                    ((validation_errors++))
                fi
            else
                echo "    ❌ Versions/Current should be a symlink"
                ((validation_errors++))
            fi
        else
            echo "    ❌ Versions/Current directory not found"
            ((validation_errors++))
        fi
    else
        echo "    No Versions directory found (standard framework structure)"
        
        # For frameworks without Versions, the binary should be a regular file
        if [ -f "$binary_path" ] && ! is_symlink "$binary_path"; then
            echo "    ✅ Main binary is not a symlink"
        else
            echo "    ❌ Main binary is a symlink or does not exist: $binary_path"
            ((validation_errors++))
        fi
    fi
}

# Find all platform-specific directories in the xcframework
platform_dirs=$(find "$XCFRAMEWORK_PATH" -maxdepth 1 -type d -not -name "*.xcframework" -not -name "." | grep -v "Info.plist" | sort)

if [ -z "$platform_dirs" ]; then
    echo "Error: No platform directories found in XCFramework"
    exit 1
fi

echo "Found platform directories:"
echo "${platform_dirs//^/  }"

echo ""
echo "Validating framework structures..."

# Validate each platform directory
while IFS= read -r platform_dir; do
    if [ -n "$platform_dir" ]; then
        echo ""
        echo "Platform: $(basename "$platform_dir")"
        
        # Find all .framework directories in this platform
        frameworks=$(find "$platform_dir" -name "*.framework" -type d)
        
        if [ -z "$frameworks" ]; then
            echo "  ⚠️ No .framework directories found"
        else
            while IFS= read -r framework; do
                if [ -n "$framework" ]; then
                    validate_framework "$framework"
                fi
            done <<< "$frameworks"
        fi
    fi
done <<< "$platform_dirs"

echo ""
echo "=========================================="
echo "Validation Summary:"

if [ $validation_errors -eq 0 ]; then
    echo "✅ All validations passed! XCFramework format is correct."
    exit 0
else
    echo "❌ Validation failed with $validation_errors error(s)."
    echo "Please fix the errors before using this XCFramework."
    exit 1
fi
