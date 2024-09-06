#!/bin/bash
set -euo pipefail

# Ensure the swizzling of network classes doesn't break the normal functionality of web requests.
# We borrow the tests of Alamofire under the MIT license: https://github.com/Alamofire/Alamofire.
# The following steps checkout Alamofire and apply a github patch to the project. The patch adds
# Sentry to the tests with auto performance monitoring enabled. While the tests are running a
# transaction is bound to the scope, so the Sentry SDK adds spans to the transaction. This doesn't
# validate if the Sentry SDK adds proper spans. It only validates that the swizzling logic
# doesn't break web request

echo "### Integration test - Alamofire ###"

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

git clone https://github.com/Alamofire/Alamofire
cd "Alamofire"
git config advice.detachedHead false
git checkout --progress --force f82c23a8a7ef8dc1a49a8bfc6a96883e79121864
git log -1 --format='%H'

cp "$scripts_path/add-local-sentry-to-alamofire.patch" "add-local-sentry-to-alamofire.patch"

git apply "add-local-sentry-to-alamofire.patch"

curl "https://github.com/Alamofire/Firewalk/releases/download/0.8.1/firewalk.zip" --output firewalk.zip -L
Unzip "firewalk.zip"
./firewalk &
firewalks_pid=$!

trap 'kill $firewalks_pid' ERR

set -o pipefail && env NSUnbufferedIO=YES \
  xcodebuild -project "Alamofire.xcodeproj" -scheme "Alamofire iOS" -destination "OS=16.4,name=iPhone 14 Pro" \
  -skip-testing:"Alamofire iOS Tests/AuthenticationInterceptorTestCase/testThatInterceptorThrowsMissingCredentialErrorWhenCredentialIsNilAndRequestShouldBeRetried" \
  -skip-testing:"Alamofire iOS Tests/AuthenticationInterceptorTestCase/testThatInterceptorRetriesRequestThatFailedWithOutdatedCredential" \
  test | xcpretty

kill $firewalks_pid
cd "$current_dir"
rm -f -r "./integration-test"
