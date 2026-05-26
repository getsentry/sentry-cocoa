#!/bin/bash
#
# Builds standalone SentryObjC xcframeworks in two linkage variants:
#
#   SentryObjC-Static.xcframework   - static archive; consumer links the symbols directly.
#   SentryObjC-Dynamic.xcframework  - dynamic library; consumer embeds the framework.
#
# Both variants bundle the four static archives (Sentry, SentryObjCTypes,
# SentryObjCBridge, SentryObjC) into a single binary so downstream consumers
# only have to link one framework, and neither requires Clang modules.
#
# Strategy per SDK slice:
#   1. libtool-merge the four .a files into a single combined static archive.
#   2. Static slice: package the combined archive as the framework binary.
#   3. Dynamic slice: re-link the combined archive as a dylib via swiftc, which
#      also handles the Swift runtime.
#   4. Flatten public headers from SentryObjCTypes into the merged framework's
#      Headers/ dir, and rewrite `<SentryObjCTypes/...>` imports in the umbrella
#      so they resolve within the single-framework layout (`<SentryObjC/...>`).
# After all slices are built, xcodebuild -create-xcframework assembles each set.

set -eoux pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

sdks=()

usage() {
    log_notice "Usage: $0"
    log_notice "  --sdk <name>    SDK to build (repeatable, e.g. --sdk iphoneos --sdk iphonesimulator)"
    log_notice ""
    log_notice "If no --sdk is given, all SDKs are built."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdk)  sdks+=("$2"); shift 2 ;;
        *)      usage ;;
    esac
done

if [ ${#sdks[@]} -eq 0 ]; then
    sdks=( iphoneos iphonesimulator macosx maccatalyst appletvos appletvsimulator watchos watchsimulator xros xrsimulator )
fi

ARCHIVE_BASE="$(pwd)/XCFrameworkBuildPath/archive"
STATIC_OUTPUT_BASE="${ARCHIVE_BASE}/SentryObjC-Standalone-Static"
DYNAMIC_OUTPUT_BASE="${ARCHIVE_BASE}/SentryObjC-Standalone-Dynamic"

# Read deployment targets from the canonical xcconfig (single source of truth).
DEPLOY_XCCONFIG="${SCRIPT_DIR}/../Sources/Configuration/DeploymentTargets.xcconfig"
echo "=== Reading deployment targets from ${DEPLOY_XCCONFIG} ==="
if [ ! -f "$DEPLOY_XCCONFIG" ]; then
    echo "ERROR: DeploymentTargets.xcconfig not found at ${DEPLOY_XCCONFIG}"
    exit 1
fi
IOS_DEPLOYMENT_TARGET=$(awk -F' = ' '/IPHONEOS_DEPLOYMENT_TARGET/{print $2}' "$DEPLOY_XCCONFIG")
MACOS_DEPLOYMENT_TARGET=$(awk -F' = ' '/MACOSX_DEPLOYMENT_TARGET/{print $2}' "$DEPLOY_XCCONFIG")
TVOS_DEPLOYMENT_TARGET=$(awk -F' = ' '/TVOS_DEPLOYMENT_TARGET/{print $2}' "$DEPLOY_XCCONFIG")
WATCHOS_DEPLOYMENT_TARGET=$(awk -F' = ' '/WATCHOS_DEPLOYMENT_TARGET/{print $2}' "$DEPLOY_XCCONFIG")
XROS_DEPLOYMENT_TARGET=$(awk -F' = ' '/XROS_DEPLOYMENT_TARGET/{print $2}' "$DEPLOY_XCCONFIG")
echo "  iOS=$IOS_DEPLOYMENT_TARGET macOS=$MACOS_DEPLOYMENT_TARGET tvOS=$TVOS_DEPLOYMENT_TARGET watchOS=$WATCHOS_DEPLOYMENT_TARGET xrOS=$XROS_DEPLOYMENT_TARGET"

for target_var in IOS_DEPLOYMENT_TARGET MACOS_DEPLOYMENT_TARGET TVOS_DEPLOYMENT_TARGET WATCHOS_DEPLOYMENT_TARGET XROS_DEPLOYMENT_TARGET; do
    if [ -z "${!target_var}" ]; then
        echo "ERROR: Could not read ${target_var} from ${DEPLOY_XCCONFIG}"
        exit 1
    fi
done

# Builds an {arch}-apple-{os}{version}[-environment] triple for a given SDK and architecture.
build_triple() {
    local sdk="$1"
    local arch="$2"
    case "$sdk" in
        iphoneos)          echo "${arch}-apple-ios${IOS_DEPLOYMENT_TARGET}" ;;
        iphonesimulator)   echo "${arch}-apple-ios${IOS_DEPLOYMENT_TARGET}-simulator" ;;
        macosx)            echo "${arch}-apple-macos${MACOS_DEPLOYMENT_TARGET}" ;;
        maccatalyst)       echo "${arch}-apple-ios${IOS_DEPLOYMENT_TARGET}-macabi" ;;
        appletvos)         echo "${arch}-apple-tvos${TVOS_DEPLOYMENT_TARGET}" ;;
        appletvsimulator)  echo "${arch}-apple-tvos${TVOS_DEPLOYMENT_TARGET}-simulator" ;;
        watchos)           echo "${arch}-apple-watchos${WATCHOS_DEPLOYMENT_TARGET}" ;;
        watchsimulator)    echo "${arch}-apple-watchos${WATCHOS_DEPLOYMENT_TARGET}-simulator" ;;
        xros)              echo "${arch}-apple-xros${XROS_DEPLOYMENT_TARGET}" ;;
        xrsimulator)       echo "${arch}-apple-xros${XROS_DEPLOYMENT_TARGET}-simulator" ;;
    esac
}

# System libraries required for all platforms (dynamic link only).
SYSTEM_LIBS=( z c++ )

# Frameworks present on every Apple platform the SDK supports.
REQUIRED_FRAMEWORKS=( Foundation CoreData CoreGraphics QuartzCore )

# Frameworks that are only present on some platforms (e.g., SystemConfiguration
# is unavailable on watchOS). Script checks existence per-SDK and skips missing ones.
CANDIDATE_WEAK_FRAMEWORKS=( SystemConfiguration AVFoundation CoreMedia CoreVideo MetricKit PDFKit SwiftUI UIKit WebKit AppKit )

copy_framework_resources() {
    local sdk="$1"
    local source_fw="$2"   # source .framework (from the staticlib xcarchive)
    local dest_fw="$3"     # destination .framework to populate

    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        local versioned="${dest_fw}/Versions/A"
        mkdir -p "$versioned"
        cp -R "${source_fw}/Versions/A/Headers" "${versioned}/Headers"
        if [ -d "${source_fw}/Versions/A/Modules" ]; then
            cp -R "${source_fw}/Versions/A/Modules" "${versioned}/Modules"
        fi
        mkdir -p "${versioned}/Resources"
        cp "${source_fw}/Versions/A/Resources/Info.plist" "${versioned}/Resources/Info.plist" 2>/dev/null || \
            cp "${source_fw}/Resources/Info.plist" "${versioned}/Resources/Info.plist" 2>/dev/null || true
        ln -sfh A "${dest_fw}/Versions/Current"
        ln -sfh Versions/Current/Headers "${dest_fw}/Headers"
        if [ -d "${versioned}/Modules" ]; then
            ln -sfh Versions/Current/Modules "${dest_fw}/Modules"
        fi
        ln -sfh Versions/Current/Resources "${dest_fw}/Resources"
        ln -sfh Versions/Current/SentryObjC "${dest_fw}/SentryObjC"
    else
        mkdir -p "$dest_fw"
        cp -R "${source_fw}/Headers" "${dest_fw}/Headers"
        if [ -d "${source_fw}/Modules" ]; then
            cp -R "${source_fw}/Modules" "${dest_fw}/Modules"
        fi
        cp "${source_fw}/Info.plist" "${dest_fw}/Info.plist" 2>/dev/null || true
    fi
}

framework_binary_path() {
    local sdk="$1"
    local fw_dir="$2"
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        echo "${fw_dir}/Versions/A/SentryObjC"
    else
        echo "${fw_dir}/SentryObjC"
    fi
}

# Copy SentryObjCTypes public headers into the merged SentryObjC framework and
# rewrite `<SentryObjCTypes/...>` imports in the umbrella to `<SentryObjC/...>`
# so they resolve against the single merged framework at consumption time.
merge_types_headers() {
    local sdk="$1"
    local types_fw="$2"    # source SentryObjCTypes.framework
    local dest_fw="$3"     # destination merged framework

    local types_headers_src
    local dest_headers
    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        types_headers_src="${types_fw}/Versions/A/Headers"
        dest_headers="${dest_fw}/Versions/A/Headers"
    else
        types_headers_src="${types_fw}/Headers"
        dest_headers="${dest_fw}/Headers"
    fi

    for h in "${types_headers_src}"/*.h; do
        [ -f "$h" ] || continue
        local name
        name="$(basename "$h")"
        # Skip the SentryObjCTypes umbrella — we merge into SentryObjC's umbrella.
        [ "$name" = "SentryObjCTypes.h" ] && continue
        cp "$h" "${dest_headers}/${name}"
    done

    local umbrella="${dest_headers}/SentryObjC.h"
    if [ -f "$umbrella" ]; then
        # BSD sed (macOS) requires the empty '' after -i.
        sed -i '' 's|<SentryObjCTypes/|<SentryObjC/|g' "$umbrella"
    fi
}

tmp_dir=""
cleanup() {
    if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
        rm -r "$tmp_dir"
    fi
    tmp_dir=""
}
trap cleanup EXIT

for sdk in "${sdks[@]}"; do
    echo "=== Building SentryObjC slices for ${sdk} ==="

    # Locate the four static archives (reuses the normal Sentry static build)
    sentry_archive="${ARCHIVE_BASE}/Sentry/${sdk}.xcarchive/Products/Library/Frameworks/Sentry.framework"
    types_archive="${ARCHIVE_BASE}/SentryObjCTypes/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjCTypes.framework"
    bridge_archive="${ARCHIVE_BASE}/SentryObjCBridge/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjCBridge.framework"
    objc_archive="${ARCHIVE_BASE}/SentryObjC/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjC.framework"

    if [ "$sdk" = "macosx" ] || [ "$sdk" = "maccatalyst" ]; then
        sentry_a="${sentry_archive}/Versions/A/Sentry"
        types_a="${types_archive}/Versions/A/SentryObjCTypes"
        bridge_a="${bridge_archive}/Versions/A/SentryObjCBridge"
        objc_a="${objc_archive}/Versions/A/SentryObjC"
    else
        sentry_a="${sentry_archive}/Sentry"
        types_a="${types_archive}/SentryObjCTypes"
        bridge_a="${bridge_archive}/SentryObjCBridge"
        objc_a="${objc_archive}/SentryObjC"
    fi

    for lib in "$sentry_a" "$types_a" "$bridge_a" "$objc_a"; do
        if [ ! -f "$lib" ]; then
            echo "ERROR: Static library not found at: $lib"
            exit 1
        fi
        echo "  Found: $lib ($(du -h "$lib" | cut -f1))"
    done

    tmp_dir="$(mktemp -d)"
    combined_a="${tmp_dir}/SentryObjC_combined_${sdk}.a"
    libtool -static "$sentry_a" "$types_a" "$bridge_a" "$objc_a" -o "$combined_a"
    echo "  Combined: $(du -h "$combined_a" | cut -f1)"

    # --- Static slice: package the combined archive as the framework binary ---
    static_fw_dir="${STATIC_OUTPUT_BASE}/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjC.framework"
    rm -rf "$static_fw_dir"
    copy_framework_resources "$sdk" "$objc_archive" "$static_fw_dir"
    merge_types_headers "$sdk" "$types_archive" "$static_fw_dir"
    cp "$combined_a" "$(framework_binary_path "$sdk" "$static_fw_dir")"
    echo "  Static binary: $(du -h "$(framework_binary_path "$sdk" "$static_fw_dir")" | cut -f1)"

    # --- Dynamic slice: re-link the combined archive into a dylib via swiftc ---
    sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path 2>/dev/null || xcrun --sdk iphoneos --show-sdk-path)"
    if [ "$sdk" = "maccatalyst" ]; then
        sysroot="$(xcrun --sdk macosx --show-sdk-path)"
    fi

    # Derive architectures and triples from the already-built static archive.
    read -r -a archs <<< "$(lipo -archs "$combined_a")"
    arch_targets=()
    for arch in "${archs[@]}"; do
        arch_targets+=( "$(build_triple "$sdk" "$arch")" )
    done

    # Discover which weak frameworks are available on this SDK.
    fw_search_path="${sysroot}/System/Library/Frameworks"
    catalyst_fw_path=""
    if [ "$sdk" = "maccatalyst" ]; then
        catalyst_fw_path="${sysroot}/System/iOSSupport/System/Library/Frameworks"
    fi

    WEAK_FRAMEWORKS=()
    for fw in "${CANDIDATE_WEAK_FRAMEWORKS[@]}"; do
        if [ -d "${fw_search_path}/${fw}.framework" ]; then
            WEAK_FRAMEWORKS+=( "$fw" )
        elif [ "$sdk" = "maccatalyst" ] && [ -d "${catalyst_fw_path}/${fw}.framework" ]; then
            WEAK_FRAMEWORKS+=( "$fw" )
        fi
    done
    echo "  Weak frameworks for ${sdk}: ${WEAK_FRAMEWORKS[*]}"

    dynamic_fw_dir="${DYNAMIC_OUTPUT_BASE}/${sdk}.xcarchive/Products/Library/Frameworks/SentryObjC.framework"
    rm -rf "$dynamic_fw_dir"
    copy_framework_resources "$sdk" "$objc_archive" "$dynamic_fw_dir"
    merge_types_headers "$sdk" "$types_archive" "$dynamic_fw_dir"

    linker_flags=()
    linker_flags+=( -Xlinker -install_name -Xlinker "@rpath/SentryObjC.framework/SentryObjC" )
    linker_flags+=( -Xlinker -rpath -Xlinker "@executable_path/Frameworks" )
    linker_flags+=( -Xlinker -force_load -Xlinker "$combined_a" )
    linker_flags+=( -Xlinker -compatibility_version -Xlinker 1.0.0 )
    linker_flags+=( -Xlinker -current_version -Xlinker 1.0.0 )
    if [ "$sdk" = "maccatalyst" ]; then
        linker_flags+=( -Xlinker -F -Xlinker "${catalyst_fw_path}" )
    fi
    for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
        linker_flags+=( -framework "$fw" )
    done
    for fw in "${WEAK_FRAMEWORKS[@]}"; do
        linker_flags+=( -Xlinker -weak_framework -Xlinker "$fw" )
    done
    for lib in "${SYSTEM_LIBS[@]}"; do
        linker_flags+=( -l"$lib" )
    done

    # swiftc -emit-library requires at least one source file; the empty file
    # lets swiftc act purely as a linker driver for the Swift runtime.
    dummy_swift="${tmp_dir}/SentryObjC_dummy.swift"
    echo "" > "$dummy_swift"

    arch_binaries=()
    for target in "${arch_targets[@]}"; do
        arch="${target%%-*}"
        echo "  Linking arch: $arch ($target)"

        arch_output="${tmp_dir}/SentryObjC_${sdk}_${arch}"
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

    dynamic_binary="$(framework_binary_path "$sdk" "$dynamic_fw_dir")"
    if [ "${#arch_binaries[@]}" -gt 1 ]; then
        xcrun lipo -create "${arch_binaries[@]}" -output "$dynamic_binary"
    else
        cp "${arch_binaries[0]}" "$dynamic_binary"
    fi
    echo "  Dynamic binary: $(du -h "$dynamic_binary" | cut -f1)"

    cleanup

    echo "=== Done: ${sdk} ==="
done

# Assemble both xcframeworks.
xcframework_sdks="$(IFS=,; echo "${sdks[*]}")"
./scripts/assemble-xcframework.sh "SentryObjC" "-Static" "" "$xcframework_sdks" "${STATIC_OUTPUT_BASE}/SDK_NAME.xcarchive"
./scripts/assemble-xcframework.sh "SentryObjC" "-Dynamic" "" "$xcframework_sdks" "${DYNAMIC_OUTPUT_BASE}/SDK_NAME.xcarchive"
