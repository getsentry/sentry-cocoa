#!/bin/bash
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

cp "$scripts_path/local-alamofire.patch" "local-alamofire.patch"

git apply "local-alamofire.patch"

curl "https://github.com/Alamofire/Firewalk/releases/download/0.8.1/firewalk.zip" --output firewalk.zip -L
Unzip "firewalk.zip"
./firewalk &
firewalks_pid=$!

trap 'kill $firewalks_pid' ERR

set -o pipefail && env NSUnbufferedIO=YES \
  xcodebuild -project "Alamofire.xcodeproj" -scheme "Alamofire iOS" \
  -skip-testing:"Alamofire iOS Tests/AuthenticationInterceptorTestCase/testThatInterceptorThrowsMissingCredentialErrorWhenCredentialIsNilAndRequestShouldBeRetried" \
  -skip-testing:"Alamofire iOS Tests/AuthenticationInterceptorTestCase/testThatInterceptorRetriesRequestThatFailedWithOutdatedCredential" \
  test | xcpretty

kill $firewalks_pid
cd "$current_dir"
rm -f -r "./integration-test"
