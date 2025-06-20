#!/usr/bin/env bash

echo "Installing gems..."
bundle install

echo "Building the sample app..."
bundle exec fastlane ui_critical_tests_ios_swiftui_all
