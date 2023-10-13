# We ship a version of Sentry that does not link UIKit. This script runs in CI to ensure we don't accidentally add any code to that configuration that re-adds it again.

#!/bin/bash

set -eou pipefail

CONFIGURATION="${1}"
DERIVED_DATA_PATH="${2}"

SENTRY_BUILD_PRODUCT_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/Sentry.framework/Sentry"

stat $SENTRY_BUILD_PRODUCT_PATH

MATCHES=$(otool -L $SENTRY_BUILD_PRODUCT_PATH | grep -c UIKit.framework ||:)
echo "hi"
if [ $MATCHES != 0 ]; then
    echo "UIKit.framework linkage found."
    exit 67
fi

echo "Success! UIKit.framework not linked."
