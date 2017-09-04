#!/bin/sh
gem install fastlane

if [ "$LANE" = "lint" ];
then
    if [ "$TRAVIS_PULL_REQUEST" != "false" ];
    then
        echo "We don't run linter for PRs, because Danger!"
        exit 0;
    fi
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
