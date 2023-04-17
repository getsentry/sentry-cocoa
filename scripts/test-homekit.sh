#!/bin/bash

#Home assistant cocoapod requires 'cocoapods-acknowledgements' plugin to work
#If you dont have it use: gem install cocoapods-acknowledgements
echo "### Integration test - Home Assistant ###"

current_dir=$(pwd)
scripts_path=$(dirname $(readlink -f "$0"))

trap 'cd "$current_dir"' ERR

if [ -d "./integration-test" ]
then
    echo "WARNING - './integration-test' directory already exists, deleting it."
    rm -f -r "./integration-test"
fi

mkdir "integration-test"

cd "integration-test"

git clone https://github.com/home-assistant/iOS
cd "iOS"
git config advice.detachedHead false
git checkout --progress --force 6d6606aed63a778c5a2bd64f8981823433a7f2fa
git log -1 --format='%H'

cp "$scripts_path/add-local-sentry-to-homekit.patch" "add-local-sentry-to-homekit.patch"

git apply "add-local-sentry-to-homekit.patch"

bundle config set --local path 'vendor/bundle'
bundle install --jobs 4 --retry 3

bundle exec pod install

bundle exec fastlane test

cd "$current_dir"
rm -f -r "./integration-test"

