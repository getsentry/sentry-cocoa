#!/bin/sh
if [ -n "$TRAVIS_TAG" ]; then
brew update
brew outdated carthage || brew upgrade carthage
cd KSCrash
carthage build --no-skip-current
carthage archive --output Sentry.framework.zip
fi
