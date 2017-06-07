#!/bin/sh
if [ -n "$TRAVIS_TAG" ]; then
gem install cocoapods
fi
