#!/usr/bin/env bash

set -eoux pipefail

search_path="$1"
scheme="$2"
suffix="$3"
IFS=',' read -r -a sdks <<< "$4"

xcodebuild_cmd="xcodebuild -create-xcframework"

for sdk in "${sdks[@]}"; do
    framework_path="$search_path/$scheme$suffix/$sdk.xcarchive/Products/Library/Frameworks/$scheme.framework"
    echo "Processing $framework_path"

    xcodebuild_cmd+=" -framework \"$framework_path\""

    dsym_path="$search_path/$scheme$suffix/$sdk.xcarchive/dSYMs/$scheme.framework.dSYM"
    if [[ -n "$dsym_path" ]]; then
        echo "Processing $dsym_path"

        xcodebuild_cmd+=" -debug-symbols \"$dsym_path\""
    fi
done

rm -rf "$scheme$suffix.xcframework"
xcodebuild_cmd+=" -output \"$scheme$suffix.xcframework\""

eval "$xcodebuild_cmd"
