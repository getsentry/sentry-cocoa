#!/bin/bash

set -x
env

# Run swiftlint for local builds so issues show up in Xcode. In CI, swiftlint is called externally and so should not run as part of building any targets.

if [[ $SENTRY_CI -eq 1 ]]; then
    echo "Detected CI environment. `swiftlint` will run in a dedicated workflow."
    exit 0;
else
    echo "Did not detect CI environment. Running swiftlint..."
fi

/opt/homebrew/bin/swiftlint lint --force-exclude
