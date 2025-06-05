#!/usr/bin/env bash

set -eoux pipefail

scheme="$1"
suffix="$2"
configuration_suffix="$3"
IFS=',' read -r -a sdks <<< "$4"

# on ci, the xcarchives live in paths like the following:
#   /path/to/.../xcframework-slices/xcframework-sentry-withoutuikit-dynamic-slice-appletvos/archive/Sentry-WithoutUIKitOrAppKit/appletvos.xcarchive
#   /path/to/.../xcframework-slices/xcframework-sentry-withoutuikit-dynamic-slice-macos/archive/Sentry-WithoutUIKitOrAppKit/macos.xcarchive
#   /path/to/.../xcframework-slices/xcframework-sentry-withoutuikit-dynamic-slice-iphoneos/archive/Sentry-WithoutUIKitOrAppKit/iphoneos.xcarchive
# in the local build script they're in something like:
#   /path/to/.../Carthage/archive/Sentry-WithoutUIKitOrAppKit/iphoneos.xcarchive
#   /path/to/.../Carthage/archive/Sentry-WithoutUIKitOrAppKit/macos.xcarchive
# the issue is that we need to inject the sdk name once into the local version, and twice into the ci version. a template string satisfies this requirement.
xcarchive_path_template="${5}" # may contain any number of instances of the template query string "SDK_NAME" that will be replaced with the actual sdk name below

xcodebuild_cmd="xcodebuild -create-xcframework"
resolved_product_name="$scheme$configuration_suffix.framework"

for sdk in "${sdks[@]}"; do
    xcarchive_path="${xcarchive_path_template//SDK_NAME/$sdk}"
    framework_path="$xcarchive_path/Products/Library/Frameworks/$resolved_product_name"
    echo "Processing $framework_path"

    xcodebuild_cmd+=" -framework \"$framework_path\""

    dsym_path="$xcarchive_path/dSYMs/$resolved_product_name.dSYM"
    if [[ -d "$dsym_path" ]]; then
        echo "Processing $dsym_path"

        xcodebuild_cmd+=" -debug-symbols \"$dsym_path\""
    fi

    if [ "$sdk" = "macosx" ]; then
        mac_catalyst_xcarchive_path="${xcarchive_path_template//SDK_NAME/maccatalyst}"
        if [[ -d "$mac_catalyst_xcarchive_path" ]]; then
            echo "Processing $mac_catalyst_xcarchive_path"

            xcodebuild_cmd+=" -framework \"$mac_catalyst_xcarchive_path/Library/Frameworks/$resolved_product_name\""

            mac_catalyst_dsym_path="$mac_catalyst_xcarchive_path/dSYMs/$resolved_product_name.dSYM"
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
