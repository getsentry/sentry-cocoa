#!/bin/bash
set -e

gem install fastlane

if [ "$LANE" = "lint" ]; then
    if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
        echo "We don't run linter for PRs, because Danger!"
        exit 0;
    fi

    gem install danger
    gem install danger-swiftlint
    brew update > /dev/null
    brew outdated swiftlint || brew upgrade swiftlint
elif [ "$LANE" = "oc_lint" ]; then
    brew brew tap oclint/formulae
    brew install oclint
elif [ "$LANE" = "pod" ]; then
    gem install cocoapods
    pod repo update
fi

fastlane $LANE

if [ "$LANE" = "test" ]; then
    gem install slather
    slather coverage --scheme Sentry && bash <(curl -s https://codecov.io/bash) -f cobertura.xml;
fi
