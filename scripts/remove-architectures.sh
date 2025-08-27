#!/bin/bash

# Script to remove specific architectures from framework binaries in XCFramework slices
# Usage: ./scripts/remove-architectures.sh <xcarchive_path> <excluded_architectures>
# Example: ./scripts/remove-architectures.sh xcframework-slices/iphoneos.xcarchive "arm64"

set -e

# Check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <xcarchive_path> <excluded_architectures>"
    echo "Example: $0 xcframework-slices/iphoneos.xcarchive \"arm64e\""
    exit 1
fi

XCARCHIVE_PATH="$1"
EXCLUDED_ARCH="$2"

# Validate that the xcarchive path exists
if [ ! -d "$XCARCHIVE_PATH" ]; then
    echo "Error: XCArchive path does not exist: $XCARCHIVE_PATH"
    exit 1
fi

# Check if excluded architectures are provided
if [ -z "$EXCLUDED_ARCH" ]; then
    echo "Warning: No excluded architecture specified. Nothing to do."
    exit 0
fi

echo "Removing architectures from frameworks in: $XCARCHIVE_PATH"
echo "Excluded architectures: $EXCLUDED_ARCH"

# Find all framework directories and process their binaries
find "$XCARCHIVE_PATH" -name "*.framework" -type d | while read -r framework_path; do
    binary_path="$framework_path/$(basename "$framework_path" .framework)"
    if [ -f "$binary_path" ]; then
        echo "Processing binary: $binary_path"
        
        # Check what architectures are currently in the binary
        echo "Current architectures in binary:"
        lipo -info "$binary_path"

        should_remove=""
        
        # Check if the excluded architectures are actually present
        if lipo -info "$binary_path" | grep -q "$EXCLUDED_ARCH"; then
            echo "Architecture '$EXCLUDED_ARCH' found in binary, will remove it"
            should_remove=true
        else
            echo "Warning: Architecture '$EXCLUDED_ARCH' not found in binary, skipping removal"
        fi
        
        # Only perform removal if there are architectures to remove
        if [ -n "$should_remove" ]; then
            echo "Removing architectures:$EXCLUDED_ARCH"
            temp_binary="${binary_path}.tmp"
            lipo -remove "$EXCLUDED_ARCH" "$binary_path" -output "$temp_binary"
            mv "$temp_binary" "$binary_path"
            echo "Updated binary: $binary_path"
        else
            echo "No architectures to remove for this binary"
        fi
    fi
done

echo "Architecture removal completed successfully." 
