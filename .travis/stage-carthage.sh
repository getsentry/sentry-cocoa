#!/bin/sh

brew update > /dev/null
brew outdated carthage || brew upgrade carthage

cd KSCrash
carthage build --no-skip-current
carthage archive --output Sentry.framework.zip
mkdir ../build
mv Sentry.framework.zip ../build
