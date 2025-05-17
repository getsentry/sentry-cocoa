#!/bin/sh

set -x

search_path=${1}
xcframework_name=${2}

framework_args=$(find "$search_path" -name "*.framework" | awk '{print "-framework $search_path/"$0}' | xargs)
dsym_args=$(find "$search_path" -name "*.framework.dSYM" | awk '{print "-debug-symbols $search_path/"$0}' | xargs)

xcodebuild -create-xcframework "$framework_args" "$dsym_args" -output "$xcframework_name.xcframework"

ditto -c -k -X --rsrc --keepParent "$xcframework_name.xcframework" "$xcframework_name.xcframework.zip"
