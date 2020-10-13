#!/bin/sh

brew update > /dev/null
brew outdated carthage || brew upgrade carthage

./scripts/carthage-xcode12-workaround.sh build --no-skip-current
./scripts/carthage-xcode12-workaround.sh archive --output Sentry.framework.zip
