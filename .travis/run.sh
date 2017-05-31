#!/bin/sh
gem install fastlane

if [ "$LANE" = "lint" ];
then
    gem install danger
    gem install danger-swiftlint
    brew update
    brew outdated swiftlint || brew upgrade swiftlint
elif [ "$LANE" = "do_cocoapods" ];
then
    gem install cocoapods
elif [ "$LANE" = "test" ];
then
    gem install slather
fi
fastlane $LANE;
