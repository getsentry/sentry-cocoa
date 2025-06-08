#!/usr/bin/env bash

set -eou pipefail

scheme="$1"
suffix="$2"
configuration_suffix="$3"
IFS=',' read -r -a sdks <<< "$4"

echo "--------------------------------"
echo "Assembling XCFramework ${scheme}${suffix} for ${4}"
echo "--------------------------------"

# on ci, the xcarchives live in paths like the following:
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-maccatalyst/Library/Frameworks/SentrySwiftUI.framework
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-macosx/Library/Frameworks/SentrySwiftUI.framework
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-iphoneos/Library/Frameworks/SentrySwiftUI.framework
# in the local build script they're in something like:
#   /path/to/.../Carthage/archive/Sentry-WithoutUIKitOrAppKit/iphoneos.xcarchive
#   /path/to/.../Carthage/archive/Sentry-WithoutUIKitOrAppKit/macos.xcarchive
# the issue is that we need to inject the sdk name once into the local version, and twice into the ci version. a template string satisfies this requirement.
xcarchive_path_template="${5}" # may contain any number of instances of the template query string "SDK_NAME" that will be replaced with the actual sdk name below

xcodebuild_cmd="xcodebuild -create-xcframework"

if [ -z "$configuration_suffix" ]; then
    resolved_product_name="$scheme"
else
    resolved_product_name="$scheme$configuration_suffix"
fi

framework_filename="$resolved_product_name.framework"

for sdk in "${sdks[@]}"; do
    xcarchive_path="${xcarchive_path_template//SDK_NAME/$sdk}"
    framework_path="$xcarchive_path/Products/Library/Frameworks/$framework_filename"
    echo "Processing $framework_path"

    xcodebuild_cmd+=" -framework \"$framework_path\""

    dsym_path="$xcarchive_path/dSYMs/$framework_filename.dSYM"
    if [[ -d "$dsym_path" ]]; then
        echo "Processing $dsym_path"

        xcodebuild_cmd+=" -debug-symbols \"$dsym_path\""
    fi

    if [ "$sdk" = "macosx" ]; then
        mac_catalyst_xcarchive_path="${xcarchive_path_template//SDK_NAME/maccatalyst}/Library/Frameworks"
        if [[ -d "$mac_catalyst_xcarchive_path" ]]; then
            echo "Processing $mac_catalyst_xcarchive_path"

            xcodebuild_cmd+=" -framework \"$mac_catalyst_xcarchive_path/$framework_filename\""

            mac_catalyst_dsym_path="$mac_catalyst_xcarchive_path/dSYMs/$framework_filename.dSYM"
            if [[ -d "$mac_catalyst_dsym_path" ]]; then
                echo "Processing $mac_catalyst_dsym_path"

                xcodebuild_cmd+=" -debug-symbols \"$mac_catalyst_dsym_path\""
            fi
        fi
    fi
done

if [ -z "$suffix" ]; then
    resolved_xcframework_name="$scheme"
else
    resolved_xcframework_name="$scheme$suffix"
fi
xcframework_filename="$resolved_xcframework_name.xcframework"
rm -rf "$xcframework_filename"
xcodebuild_cmd+=" -output \"$xcframework_filename\""

eval "$xcodebuild_cmd"
