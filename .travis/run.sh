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
    pod repo update
elif [ "$LANE" = "test" ];
then
    gem install slather
fi
fastlane $LANE

