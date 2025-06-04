#!/usr/bin/env bash

set -x

search_path="$1"
xcframework_name="$2"

xcodebuild_cmd="xcodebuild -create-xcframework"

for slice_dir in "$search_path"/xcframework-*; do
    framework_path=$(find "$slice_dir" -name '*.framework' -print -quit)
    dsym_path=$(find "$slice_dir" -name '*.framework.dSYM' -print -quit)

    if [[ -n "$framework_path" ]]; then
        xcodebuild_cmd+=" -framework \"$framework_path\""

        if [[ -n "$dsym_path" ]]; then
            xcodebuild_cmd+=" -debug-symbols \"$dsym_path\""
        fi
    fi
done

xcodebuild_cmd+=" -output \"$xcframework_name.xcframework\""

eval "$xcodebuild_cmd"
