#!/bin/bash
#
# Links three pre-built static archives (Sentry, SentryObjCBridge, SentryObjC)
# into a standalone dynamic SentryObjC.framework for each SDK slice, then
# assembles them into an XCFramework.
#
# Strategy:
#   1. Merge all three .a files with libtool
#   2. Link into a dynamic library with swiftc (handles Swift runtime automatically)
#   3. Copy SentryObjC public headers + module map
#   4. Assemble into XCFramework
#
# Parameters:
#   $1 - sdks_to_build (AllSDKs, iOSOnly, macOSOnly, etc.)

set -eoux pipefail

sdks_to_build="${1:-AllSDKs}"

if [ "$sdks_to_build" = "iOSOnly" ]; then
    sdks=( iphoneos iphonesimulator )
elif [ "$sdks_to_build" = "macOSOnly" ]; then
    sdks=( macosx )
elif [ "$sdks_to_build" = "macCatalystOnly" ]; then
    sdks=( maccatalyst )
else
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

ARCHIVE_BASE="$(pwd)/XCFrameworkBuildPath/archive"
OUTPUT_BASE="$(pwd)/XCFrameworkBuildPath/archive/SentryObjC"

# System frameworks and libraries.
# Platform-specific lists are set inside the loop below.
SYSTEM_LIBS=( z c++ )

for sdk in "${sdks[@]}"; do
    echo "=== Linking standalone SentryObjC for ${sdk} ==="

    # Locate the three static archives
    sentry_archive="${ARCHIVE_BASE}/Sentry-ForEmbedding/${sdk}.xcarchive/Products/Library/Frameworks/Sentry.framework"
    bridge_archive="${ARCHIVE_BASE}/SentryObjCBridge-ForEmbedding/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjCBridge.framework"
    objc_archive="${ARCHIVE_BASE}/SentryObjC-ForEmbedding/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjC.framework"

    # Get the actual binary paths (macOS uses Versions/A structure)
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        sentry_a="${sentry_archive}/Versions/A/Sentry"
        bridge_a="${bridge_archive}/Versions/A/SentryObjCBridge"
        objc_a="${objc_archive}/Versions/A/SentryObjC"
    else
        sentry_a="${sentry_archive}/Sentry"
        bridge_a="${bridge_archive}/SentryObjCBridge"
        objc_a="${objc_archive}/SentryObjC"
    fi

    for lib in "$sentry_a" "$bridge_a" "$objc_a"; do
        if [ ! -f "$lib" ]; then
            echo "ERROR: Static library not found at: $lib"
            exit 1
        fi
        echo "  Found: $lib ($(du -h "$lib" | cut -f1))"
    done

    # Merge into one static archive
    combined_a="/tmp/SentryObjC_combined_${sdk}.a"
    libtool -static "$sentry_a" "$bridge_a" "$objc_a" -o "$combined_a"
    echo "  Combined: $(du -h "$combined_a" | cut -f1)"

    # Determine target triple(s) per architecture
    sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path 2>/dev/null || xcrun --sdk iphoneos --show-sdk-path)"
    case "$sdk" in
        iphoneos)          arch_targets=( "arm64-apple-ios15.0" ) ;;
        iphonesimulator)   arch_targets=( "arm64-apple-ios15.0-simulator" "x86_64-apple-ios15.0-simulator" ) ;;
        macosx)            arch_targets=( "arm64-apple-macos10.14" "x86_64-apple-macos10.14" ) ;;
        maccatalyst)       arch_targets=( "arm64-apple-ios15.0-macabi" "x86_64-apple-ios15.0-macabi" )
                           sysroot="$(xcrun --sdk macosx --show-sdk-path)" ;;
        appletvos)         arch_targets=( "arm64-apple-tvos15.0" ) ;;
        appletvsimulator)  arch_targets=( "arm64-apple-tvos15.0-simulator" "x86_64-apple-tvos15.0-simulator" ) ;;
        watchos)           arch_targets=( "arm64-apple-watchos8.0" "arm64_32-apple-watchos8.0" ) ;;
        watchsimulator)    arch_targets=( "arm64-apple-watchos8.0-simulator" "x86_64-apple-watchos8.0-simulator" ) ;;
        xros)              arch_targets=( "arm64-apple-xros1.0" ) ;;
        xrsimulator)       arch_targets=( "arm64-apple-xros1.0-simulator" ) ;;
    esac

    # Platform-specific framework lists
    REQUIRED_FRAMEWORKS=( Foundation CoreData SystemConfiguration CoreGraphics QuartzCore )
    case "$sdk" in
        macosx)
            WEAK_FRAMEWORKS=( AVFoundation CoreMedia CoreVideo MetricKit PDFKit SwiftUI WebKit AppKit ) ;;
        watchos|watchsimulator)
            WEAK_FRAMEWORKS=( ) ;;
        *)
            WEAK_FRAMEWORKS=( AVFoundation CoreMedia CoreVideo MetricKit PDFKit SwiftUI UIKit WebKit ) ;;
    esac

    # Prepare output framework directory
    output_xcarchive="${OUTPUT_BASE}/${sdk}.xcarchive"
    output_fw_dir="${output_xcarchive}/Products/Library/Frameworks/SentryObjC.framework"

    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        output_fw_binary_dir="${output_fw_dir}/Versions/A"
        mkdir -p "${output_fw_binary_dir}"
    else
        output_fw_binary_dir="${output_fw_dir}"
        mkdir -p "${output_fw_dir}"
    fi

    # Build linker flags (same for all archs)
    linker_flags=()
    linker_flags+=( -Xlinker -install_name -Xlinker "@rpath/SentryObjC.framework/SentryObjC" )
    linker_flags+=( -Xlinker -rpath -Xlinker "@executable_path/Frameworks" )
    linker_flags+=( -Xlinker -force_load -Xlinker "$combined_a" )
    linker_flags+=( -Xlinker -compatibility_version -Xlinker 1.0.0 )
    linker_flags+=( -Xlinker -current_version -Xlinker 1.0.0 )
    for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
        linker_flags+=( -framework "$fw" )
    done
    for fw in "${WEAK_FRAMEWORKS[@]}"; do
        linker_flags+=( -Xlinker -weak_framework -Xlinker "$fw" )
    done
    for lib in "${SYSTEM_LIBS[@]}"; do
        linker_flags+=( -l"$lib" )
    done

    # Link each architecture separately, then merge with lipo
    # swiftc needs a dummy .swift input but handles Swift runtime automatically
    dummy_swift="/tmp/SentryObjC_dummy.swift"
    echo "" > "$dummy_swift"

    arch_binaries=()
    for target in "${arch_targets[@]}"; do
        arch="${target%%-*}"
        echo "  Linking arch: $arch ($target)"

        arch_output="/tmp/SentryObjC_${sdk}_${arch}"
        xcrun swiftc \
            "$dummy_swift" \
            -emit-library \
            -target "$target" \
            -sdk "$sysroot" \
            "${linker_flags[@]}" \
            -o "$arch_output" 2>&1 || {
                echo "ERROR: Failed to link arch $arch for $sdk"
                exit 1
            }
        arch_binaries+=("$arch_output")
    done

    # Merge architectures with lipo if multiple
    if [ "${#arch_binaries[@]}" -gt 1 ]; then
        xcrun lipo -create "${arch_binaries[@]}" -output "${output_fw_binary_dir}/SentryObjC"
    else
        cp "${arch_binaries[0]}" "${output_fw_binary_dir}/SentryObjC"
    fi

    echo "  Final binary: $(du -h "${output_fw_binary_dir}/SentryObjC" | cut -f1)"

    # Copy headers and module map from the SentryObjC static build
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        cp -R "${objc_archive}/Versions/A/Headers" "${output_fw_binary_dir}/Headers"
        cp -R "${objc_archive}/Versions/A/Modules" "${output_fw_binary_dir}/Modules"
        mkdir -p "${output_fw_binary_dir}/Resources"
        cp "${objc_archive}/Versions/A/Resources/Info.plist" "${output_fw_binary_dir}/Resources/Info.plist" 2>/dev/null || \
            cp "${objc_archive}/Resources/Info.plist" "${output_fw_binary_dir}/Resources/Info.plist" 2>/dev/null || true
        # Create standard macOS framework symlinks
        ln -sfh A "${output_fw_dir}/Versions/Current"
        ln -sfh Versions/Current/Headers "${output_fw_dir}/Headers"
        ln -sfh Versions/Current/Modules "${output_fw_dir}/Modules"
        ln -sfh Versions/Current/SentryObjC "${output_fw_dir}/SentryObjC"
    else
        cp -R "${objc_archive}/Headers" "${output_fw_dir}/Headers"
        cp -R "${objc_archive}/Modules" "${output_fw_dir}/Modules"
        cp "${objc_archive}/Info.plist" "${output_fw_dir}/Info.plist" 2>/dev/null || true
    fi

    # Clean up temp files
    rm -f "$combined_a" "$dummy_swift"
    rm -f /tmp/SentryObjC_"${sdk}"_*

    echo "=== Done: ${sdk} ==="
done

# Assemble the XCFramework from all slices
xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "SentryObjC" "" "" "$xcframework_sdks" "$(pwd)/XCFrameworkBuildPath/archive/SentryObjC/SDK_NAME.xcarchive"
