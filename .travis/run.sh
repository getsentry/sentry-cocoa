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
    echo y | fastlane snapshot reset_simulators
elif [ "$LANE" = "test_swift" ];
then
    gem install slather
    echo y | fastlane snapshot reset_simulators
fi
fastlane $LANE;
