#!/bin/bash
# Check a shipping product (from either producer) without using its build intermediates.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

framework=""
sdks=AllSDKs
usage() {
    log_info "Usage: $0 -x|--xcframework PATH [-d|--sdks comma-separated SDKs]"
    log_info "  -x, --xcframework  Unpacked shipping SDK XCFramework, with its release basename"
    log_info "  -d, --sdks         Expected SDKs (default: AllSDKs for a full release)"
    exit 1
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--xcframework) framework="${2:?Missing framework}"; shift 2 ;;
        -d|--sdks) sdks="${2:?Missing SDK list}"; shift 2 ;;
        *) usage ;;
    esac
done
[[ -d "$framework" && -n "$sdks" ]] || usage
framework="$(cd "$framework" && pwd)"
variant="$(basename "$framework" .xcframework)"
module=Sentry
arm64e=true
case "$variant" in
    Sentry-Dynamic) arm64e=false ;;
    SentryV10-Dynamic|Sentry-Dynamic-WithARM64e) ;;
    *) log_error "Unknown shipping SDK: $variant"; exit 1 ;;
esac
if [[ "$sdks" == AllSDKs ]]; then
    sdks=iphoneos,iphonesimulator,macosx,maccatalyst,appletvos,appletvsimulator,watchos,watchsimulator,xros,xrsimulator
fi
IFS=, read -r -a expected <<< "$sdks"
manifest="$(plutil -convert json -o - "$framework/Info.plist")"
[[ $(jq '.AvailableLibraries | length' <<< "$manifest") -eq ${#expected[@]} ]] || { log_error 'Wrong number of slices'; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$SCRIPT_DIR/../Tests/ShippingVariantConsumer/main.swift" "$work/"
cd "$work"
for sdk in "${expected[@]}"; do
    # Release deployment targets; device and simulator platforms are distinct contracts.
    archs=(arm64); platform_variant=""; suffix=""; sys_sdk="$sdk"
    # Numeric platform identifiers are part of Mach-O's LC_BUILD_VERSION (mach-o/loader.h).
    case "$sdk" in
        iphoneos|iphonesimulator) platform=ios; os=ios; minimum=15.0; platform_id=2; simulator_id=7 ;;
        macosx) platform=macos; os=macos; minimum=12.0; platform_id=1; archs+=(x86_64) ;;
        maccatalyst) platform=ios; os=ios; minimum=15.0; platform_id=6; archs+=(x86_64); platform_variant=maccatalyst; suffix=-macabi; sys_sdk=macosx ;;
        appletvos|appletvsimulator) platform=tvos; os=tvos; minimum=15.0; platform_id=3; simulator_id=8 ;;
        watchos|watchsimulator) platform=watchos; os=watchos; minimum=9.0; platform_id=4; simulator_id=9 ;;
        xros|xrsimulator) platform=xros; os=xros; minimum=1.0; platform_id=11; simulator_id=12 ;;
        *) usage ;;
    esac
    if [[ "$sdk" == *simulator ]]; then
        platform_variant=simulator; suffix=-simulator; platform_id=$simulator_id
        archs+=(x86_64)
    else
        if [[ "$sdk" == watchos ]]; then archs+=(arm64_32); fi
        if [[ "$arm64e" == true ]]; then archs+=(arm64e); fi
    fi
    id="$(jq -er --arg p "$platform" --arg v "$platform_variant" --arg m "$module.framework" --arg a "${archs[*]}" '
        .AvailableLibraries[] | select(.SupportedPlatform == $p and (.SupportedPlatformVariant // "") == $v
        and .LibraryPath == $m and (.SupportedArchitectures|sort) == ($a|split(" ")|sort)) | .LibraryIdentifier' <<< "$manifest")" || {
        log_error "$variant does not have the shipping $sdk slice (${archs[*]}, $module.framework)"; exit 1;
    }
    mkdir "$sdk"
    cp -R "$framework/$id/$module.framework" "$sdk/"
    binary="$sdk/$module.framework/$module"
    sdk_path="$(xcrun --sdk "$sys_sdk" --show-sdk-path)"
    for arch in "${archs[@]}"; do
        log_info "Checking $variant: $sdk/$arch"
        commands="$(xcrun otool -arch "$arch" -l "$binary")"
        grep -q 'cmd LC_ID_DYLIB' <<< "$commands" || { log_error "Not a dylib: $binary"; exit 1; }
        if [[ "$sdk" != watch* ]] && ! grep -q 'cmd LC_ATOM_INFO' <<< "$commands"; then
            log_error "Missing mergeable metadata: $binary ($arch)"; exit 1
        fi
        highest="$(awk '$1 == "minos" { print $2 }' <<< "$commands" | sort -V | tail -1)"
        platforms="$(awk '$1 == "platform" { print $2 }' <<< "$commands" | sort -u)"
        expected_min=$minimum
        # Newer watch SDKs can raise the LP64 device floor to 26. Inspect the producer's
        # load command, not the validating machine's linker; older slices still support 9.
        if [[ "$sdk" == watchos && "$arch" != arm64_32 && "$highest" == 26.0 ]] &&
            awk '$1 == "minos" { minos = $2 } $1 == "sdk" && minos == 26 && int($2) >= 26 { found = 1 } END { exit !found }' <<< "$commands"; then
            expected_min=26.0
        fi
        target="$arch-apple-$os$expected_min$suffix"
        if [[ "$platforms" != "$platform_id" || "$highest" != "$expected_min" ]]; then
            log_error "Wrong Mach-O metadata for $target: expected platform $platform_id / $expected_min, found $platforms / $highest"; exit 1
        fi
        args=(-target "$target" -F "$sdk" -sdk "$sdk_path" -module-cache-path "cache-$sdk")
        if [[ "$sdk" == maccatalyst ]]; then args+=(-Fsystem "$sdk_path/System/iOSSupport/System/Library/Frameworks"); fi
        xcrun --sdk "$sys_sdk" swiftc "${args[@]}" main.swift -framework "$module" -Xlinker -rpath -Xlinker "@executable_path/$sdk" -o consumer
        if [[ "$sdk" == macosx && "$arch" == "$(uname -m)" ]]; then ./consumer; fi
    done
done
