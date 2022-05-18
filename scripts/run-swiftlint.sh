#!/bin/bash

set -x
env

# Run swiftlint for local builds so issues show up in Xcode. In CI, swiftlint is called externally and so should not run as part of building any targets.

if [[ -n ${CI+x} ]]; then
    echo "Detected CI environment. `swiftlint` will run in a dedicated workflow."
    exit 0;
fi

/opt/homebrew/bin/swiftlint lint --force-exclude
