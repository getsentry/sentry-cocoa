#!/bin/bash

# We ship a version of Sentry that does not link UIKit. This script runs in CI to ensure we don't accidentally add any code to that configuration that re-adds it again.

set -eou pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

CONFIGURATION="${1}"
DERIVED_DATA_PATH="${2}"
LINKAGE_TEST="${3}"
MODULE_NAME="${4}"

log_notice "Checking UIKit linkage for:"
log_notice " - Configuration:     $CONFIGURATION"
log_notice " - Derived Data Path: $DERIVED_DATA_PATH"
log_notice " - Linkage Test:      $LINKAGE_TEST"
log_notice " - Module Name:       $MODULE_NAME"

# Define the path to the Sentry build product.
SENTRY_BUILD_PRODUCT_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$MODULE_NAME.framework/$MODULE_NAME"
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

# Check if the binary is linked to UIKit.
log_notice "Checking if Sentry build product is linked to UIKit."
MATCHES=$(otool -L "$SENTRY_BUILD_PRODUCT_PATH" | grep -c -e "UIKit.framework/UIKit" -e "libswiftUIKit.dylib" ||:)

# Check the linkage.
case "$LINKAGE_TEST" in
"linked")
    log_notice "Checking if Sentry build product is linked to UIKit."
    if [ "$MATCHES" == 0 ]; then
        log_error "UIKit.framework linkage not found, but expected linkage."
        exit 1
    fi
    log_notice "Success! UIKit.framework linked."
    ;;
"unlinked")
    log_notice "Checking if Sentry build product is not linked to UIKit."
    if [ "$MATCHES" != 0 ]; then
        log_error "UIKit.framework linkage found, but expected no linkage."
        exit 1
    fi
    log_notice "Success! UIKit.framework not linked."
    ;;
*)
    log_error "Provide an argument for either 'linked' or 'unlinked' UIKit check."
    exit 1
    ;;
esac
