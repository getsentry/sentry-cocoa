#!/usr/bin/env bash

set -eoux pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <scheme> <suffix> <configuration_suffix> <sdks> <xcarchive_path_template>

Assembles an XCFramework from per-SDK xcarchive slices.

ARGUMENTS:
    scheme                      Xcode scheme name (e.g., Sentry)
    suffix                      Suffix for the output xcframework name (can be empty)
    configuration_suffix        Suffix for the product name inside archives (can be empty)
    sdks                        Comma-separated list of SDKs (e.g., iphoneos,macosx)
    xcarchive_path_template     Path template with SDK_NAME placeholder(s)

EXAMPLES:
    $(basename "$0") Sentry "" "" "iphoneos,macosx" "/path/to/SDK_NAME.xcarchive"

EOF
    exit 1
}

if [ $# -lt 5 ]; then
    log_error "Expected 5 arguments, got $#"
    usage
fi

scheme="$1"
suffix="$2"
configuration_suffix="$3"
IFS=',' read -r -a sdks <<< "$4"

echo "Assembling XCFramework:"
echo "  Scheme:               $scheme"
echo "  Suffix:               ${suffix:-(none)}"
echo "  Configuration suffix: ${configuration_suffix:-(none)}"
echo "  SDKs:                 ${sdks[*]}"
echo "  Archive template:     $5"

# on ci, the xcarchives live in paths like the following:
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-maccatalyst/Library/Frameworks/SentrySwiftUI.framework
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-macosx/Library/Frameworks/SentrySwiftUI.framework
#   /path/to/.../xcframework-slices/xcframework-sentry-swiftui-slice-iphoneos/Library/Frameworks/SentrySwiftUI.framework
# in the local build script they're in something like:
#   /path/to/.../XCFrameworkBuildPath/archive/Sentry-WithoutUIKitOrAppKit/iphoneos.xcarchive
#   /path/to/.../XCFrameworkBuildPath/archive/Sentry-WithoutUIKitOrAppKit/macos.xcarchive
# the issue is that we need to inject the sdk name once into the local version, and twice into the ci version. a template string satisfies this requirement.
xcarchive_path_template="${5}" # may contain any number of instances of the template query string "SDK_NAME" that will be replaced with the actual sdk name below

xcodebuild_cmd="xcodebuild -create-xcframework"

if [ -z "$configuration_suffix" ]; then
    resolved_product_name="$scheme"
else
    resolved_product_name="$scheme$configuration_suffix"
fi

framework_filename="$resolved_product_name.framework"

begin_group "Collecting framework slices"
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
end_group

if [ -z "$suffix" ]; then
    resolved_xcframework_name="$scheme"
else
    resolved_xcframework_name="$scheme$suffix"
fi
xcframework_filename="$resolved_xcframework_name.xcframework"
rm -rf "$xcframework_filename"
xcodebuild_cmd+=" -output \"$xcframework_filename\""

begin_group "Creating $xcframework_filename"
eval "$xcodebuild_cmd"
end_group
