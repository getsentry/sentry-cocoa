#!/usr/bin/env bash

set -eoux pipefail

search_path="$1"
scheme="$2"
suffix="$3"
IFS=',' read -r -a sdks <<< "$4"

xcodebuild_cmd="xcodebuild -create-xcframework"

for sdk in "${sdks[@]}"; do
    xcarchive_path="$search_path/$scheme$suffix/$sdk.xcarchive"
    framework_path="$xcarchive_path/Products/Library/Frameworks/$scheme.framework"
    echo "Processing $framework_path"

    xcodebuild_cmd+=" -framework \"$framework_path\""

    dsym_path="$xcarchive_path/dSYMs/$scheme.framework.dSYM"
    if [[ -d "$dsym_path" ]]; then
        echo "Processing $dsym_path"

        xcodebuild_cmd+=" -debug-symbols \"$dsym_path\""
    fi

    if [ "$sdk" = "macosx" ]; then
        mac_catalyst_path="$search_path/$scheme$suffix/maccatalyst.xcarchive"
        if [[ -d "$mac_catalyst_path" ]]; then
            echo "Processing $mac_catalyst_path"

            xcodebuild_cmd+=" -framework \"$mac_catalyst_path/Library/Frameworks/$scheme.framework\""

            mac_catalyst_dsym_path="$mac_catalyst_path/dSYMs/$scheme.framework.dSYM"
            if [[ -d "$mac_catalyst_dsym_path" ]]; then
                echo "Processing $mac_catalyst_dsym_path"

                xcodebuild_cmd+=" -debug-symbols \"$mac_catalyst_dsym_path\""
            fi
        fi
    fi
done

rm -rf "$scheme$suffix.xcframework"
xcodebuild_cmd+=" -output \"$scheme$suffix.xcframework\""

eval "$xcodebuild_cmd"
