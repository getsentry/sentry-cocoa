#!/bin/sh
gem install fastlane

if [ "$LANE" = "lint" ];
then
    gem install danger
    gem install danger-swiftlint
    brew update
    brew outdated swiftlint || brew upgrade swiftlint
elif [ "$LANE" = "pod" ];
then
    gem install cocoapods
    brew update
    brew outdated carthage || brew upgrade carthage
elif [ "$LANE" = "test" ];
then
    gem install slather
fi
fastlane $LANE;

