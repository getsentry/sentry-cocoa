#!/bin/sh
if [ -n "$TRAVIS_TAG" ]; then
gem install cocoapods
pod repo update
fi
