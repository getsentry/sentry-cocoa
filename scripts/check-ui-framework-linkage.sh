#!/bin/bash

# This script checks framework linkage (UIKit or AppKit) in Sentry builds.
# We ship versions of Sentry with specific framework linkage requirements, and this script
# runs in CI to ensure we don't accidentally add any code that violates those requirements.

set -eou pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

CONFIGURATION="${1}"
DERIVED_DATA_PATH="${2}"
LINKAGE_TEST="${3}"
MODULE_NAME="${4}"
FRAMEWORK_TYPE="${5:-UIKit}" # Default to UIKit for backward compatibility

log_notice "Checking ${FRAMEWORK_TYPE} linkage for:"
log_notice " - Configuration:     $CONFIGURATION"
log_notice " - Derived Data Path: $DERIVED_DATA_PATH"
log_notice " - Linkage Test:      $LINKAGE_TEST"
log_notice " - Module Name:       $MODULE_NAME"
log_notice " - Framework Type:    $FRAMEWORK_TYPE"

# Define the path to the Sentry build product.
# Find the framework in the Build/Products directory (supports different platform suffixes like -iphonesimulator, -macosx, etc.)
SENTRY_BUILD_PRODUCT_PATH=$(find "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"* -name "$MODULE_NAME.framework" -type d 2>/dev/null | head -1)

if [ -z "$SENTRY_BUILD_PRODUCT_PATH" ]; then
    log_error "Sentry framework not found in $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION*"
    exit 1
fi

# Append the module name to get the binary path
SENTRY_BUILD_PRODUCT_PATH="$SENTRY_BUILD_PRODUCT_PATH/$MODULE_NAME"
log_notice "Checking build product path: $SENTRY_BUILD_PRODUCT_PATH"

if [ ! -f "$SENTRY_BUILD_PRODUCT_PATH" ]; then
    log_error "Sentry build product not found at path: $SENTRY_BUILD_PRODUCT_PATH"
    exit 1
fi

# For some frameworks, the binary in the framework root is a symlink to the binary in the Versions directory.
# We need to check resolve the symlink and check the binary in the Versions directory.
if [ -L "$SENTRY_BUILD_PRODUCT_PATH" ]; then
    log_notice "Sentry build product is a symlink, resolving it."
    SENTRY_BUILD_PRODUCT_PATH=$(readlink -f "$SENTRY_BUILD_PRODUCT_PATH")
    if [ ! -f "$SENTRY_BUILD_PRODUCT_PATH" ]; then
        log_error "Sentry build product not found at path: $SENTRY_BUILD_PRODUCT_PATH"
        exit 1
    fi
    log_notice "Resolved Sentry build product path: $SENTRY_BUILD_PRODUCT_PATH"
fi

# Check if the binary is linked to the specified framework.
log_notice "Checking if Sentry build product is linked to ${FRAMEWORK_TYPE}."
OTOOL_OUTPUT=$(otool -L "$SENTRY_BUILD_PRODUCT_PATH")
begin_group "OTool output"
echo "$OTOOL_OUTPUT"
end_group

# Set the grep pattern based on the framework type
if [ "$FRAMEWORK_TYPE" = "UIKit" ]; then
    MATCHES=$(echo "$OTOOL_OUTPUT" | grep -c -e "UIKit.framework/UIKit" -e "libswiftUIKit.dylib" ||:)
elif [ "$FRAMEWORK_TYPE" = "AppKit" ]; then
    MATCHES=$(echo "$OTOOL_OUTPUT" | grep -c -e "/System/Library/Frameworks/AppKit.framework/Versions/" -e "libswiftAppKit.dylib" ||:)
else
    log_error "Invalid framework type: $FRAMEWORK_TYPE. Must be 'UIKit' or 'AppKit'."
    exit 1
fi
log_notice "Matches: $MATCHES"

# Check the linkage.
case "$LINKAGE_TEST" in
"linked")
    if [ "$MATCHES" == 0 ]; then
        log_error "${FRAMEWORK_TYPE}.framework linkage not found, but expected linkage."
        exit 1
    fi
    log_notice "Success! ${FRAMEWORK_TYPE}.framework linked."
    ;;
"unlinked")
    log_notice "Checking if Sentry build product is not linked to ${FRAMEWORK_TYPE}."
    if [ "$MATCHES" != 0 ]; then
        log_error "${FRAMEWORK_TYPE}.framework linkage found, but expected no linkage."
        exit 1
    fi
    log_notice "Success! ${FRAMEWORK_TYPE}.framework not linked."
    ;;
*)
    log_error "Provide an argument for either 'linked' or 'unlinked' check."
    exit 1
    ;;
esac
