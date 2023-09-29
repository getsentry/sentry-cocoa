# We ship a version of Sentry that does not link UIKit. This script runs in CI to ensure we don't accidentally add any code to that configuration that re-adds it again.

#!/bin/bash

CONFIGURATION="${1}"
DERIVED_DATA_PATH="${2}"

MATCHES=$(otool -L $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/Sentry.framework/Sentry | grep -c UIKit.framework)
if [ $MATCHES != 0 ]; then
    echo "UIKit.framework linkage found."
    exit 67
fi

echo "Success! UIKit.framework not linked."
