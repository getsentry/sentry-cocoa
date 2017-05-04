#!/bin/sh
gem install fastlane

# gem "cocoapods"
# gem "fastlane"
# gem "slather", :group => :coverage

if [ "$LANE" = "lint" ];
then
    gem install danger
    gem install danger-swiftlint
    brew update
    brew outdated swiftlint || brew upgrade swiftlint
elif [ "$LANE" = "do_cocoapods" ] ; then
    gem install cocoapods
else
    #travis_retry fastlane $LANE;
fi
fastlane $LANE;
