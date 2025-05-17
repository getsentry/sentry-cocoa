#!/bin/sh

set -x

search_path=${1}
xcframework_name=${2}

framework_args=$(find "$search_path" -name "*.framework" | awk -v sp="$search_path" '{print "-framework " sp "/" $0}' | xargs)
dsym_args=$(find "$search_path" -name "*.framework.dSYM" | awk -v sp="$search_path" '{print "-debug-symbols " sp "/" $0}' | xargs)

xcodebuild -create-xcframework "$framework_args" "$dsym_args" -output "$xcframework_name.xcframework"

ditto -c -k -X --rsrc --keepParent "$xcframework_name.xcframework" "$xcframework_name.xcframework.zip"
