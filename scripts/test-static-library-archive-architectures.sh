#!/bin/bash
# Exercise the real static-library packager with tiny Mach-O archive products.
# Compilation, linking, libtool and lipo are real; xcodebuild supplies fixture products.
# nm and strip delegate to the real tools except in explicit fault-injection cases.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
WORK_DIR=""

usage() {
    log_info "Usage: $0 [-w|--work-dir PATH]"
    log_info "  -w, --work-dir PATH    Retain fixtures and logs in a new directory (optional)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--work-dir) [ $# -ge 2 ] || usage; WORK_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done

if [ -n "$WORK_DIR" ]; then
    if [ -e "$WORK_DIR" ]; then log_error "Work directory already exists: $WORK_DIR"; exit 1; fi
    mkdir -p "$WORK_DIR"
    WORK_DIR="$(cd "$WORK_DIR" && pwd)"
else
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
fi

log_info "Evidence: $WORK_DIR"
mkdir -p "$WORK_DIR/tools" "$WORK_DIR/package" "$WORK_DIR/objects"

printf '// Fixture package, archive invocation is stubbed.\n' > "$WORK_DIR/package/Package.swift"
mkdir -p "$WORK_DIR/package/Sources/Configuration"
printf 'MARKETING_VERSION = 9.33.0\n' > "$WORK_DIR/package/Sources/Configuration/Versioning.xcconfig"
# Model a generated *_vers.o: data-only arm64_32 objects retain OSO records after strip -S.
printf 'const double target_marker = 9.35;\n' > "$WORK_DIR/target.c"
printf 'int dependency_marker(void) { return 1; }\n' > "$WORK_DIR/dependency.c"
printf '\n' > "$WORK_DIR/empty.c"
cat > "$WORK_DIR/category.m" <<'OBJC'
__attribute__((objc_root_class))
@interface FixtureLogger
@end
@interface FixtureLogger (FormatString)
- (int)formatMarker;
@end
@implementation FixtureLogger (FormatString)
- (int)formatMarker { return 42; }
@end
OBJC

cat > "$WORK_DIR/tools/xcodebuild" <<'SH'
#!/bin/bash
set -euo pipefail
[ "${1:-}" = -list ] && exit 0
[ "${1:-}" = archive ] || exit 1
while [[ $# -gt 0 ]]; do
    if [ "$1" = -scheme ]; then
        [ "$2" = "$EXPECTED_SCHEME" ] || exit 1
        echo 'Using precompiled fixture archive products.'
        exit 0
    fi
    shift
done
exit 1
SH
# A failing nm can emit valid partial output before failing. The packager must not
# mistake that failure for "no debug maps", even when grep would find OSO records.
cat > "$WORK_DIR/tools/nm" <<'SH'
#!/bin/bash
set -euo pipefail
binary="${!#}"
archs="$(xcrun lipo -archs "$binary")"
if [[ "$PACKAGING_FAULT" = unused-architecture && "$archs" == *armv7k* ]]; then
    echo 'injected unused-architecture inspection failure' >&2
    exit 42
fi
if [[ "$archs" == *arm64_32* ]] && { [ "$PACKAGING_FAULT" = nm-error ] || \
    { [ "$PACKAGING_FAULT" = nm-after-strip-error ] && [ -f "$binary.stripped" ]; }; }; then
    "$REAL_NM" "$@"
    echo 'injected nm failure (arm64_32)' >&2
    exit 42
fi
exec "$REAL_NM" "$@"
SH
cat > "$WORK_DIR/tools/strip" <<'SH'
#!/bin/bash
set -euo pipefail
binary="${!#}"
case "$PACKAGING_FAULT" in
    strip-error) echo 'injected strip failure' >&2; exit 42 ;;
    strip-noop) exit 0 ;;
esac
"$REAL_STRIP" "$@"
if [ "$PACKAGING_FAULT" = nm-after-strip-error ]; then touch "$binary.stripped"; fi
SH
chmod +x "$WORK_DIR/tools/"*
real_nm="$(xcrun --find nm)"
real_strip="$(xcrun --find strip)"

sysroot="$(xcrun --sdk watchos --show-sdk-path)"
for arch in arm64 arm64_32; do
    for source in target.c dependency.c category.m; do
        fixture="${source%.*}"
        xcrun --sdk watchos clang -target "$arch-apple-watchos9.0" -isysroot "$sysroot" \
            -g -c "$WORK_DIR/$source" -o "$WORK_DIR/objects/$fixture-$arch-source.o"
        # Model Xcode's per-target relocatable link, which creates external OSO maps.
        xcrun --sdk watchos clang -target "$arch-apple-watchos9.0" -isysroot "$sysroot" \
            -r -nostdlib "$WORK_DIR/objects/$fixture-$arch-source.o" -o "$WORK_DIR/objects/$fixture-$arch.o"
        fixture_symbols="$(nm -ap "$WORK_DIR/objects/$fixture-$arch.o")"
        if ! grep ' OSO ' <<< "$fixture_symbols" > /dev/null; then
            log_error "Fixture must contain debug maps: $fixture-$arch.o"
            exit 1
        fi
    done
    # Categories without global definitions must survive stripping and archive assembly.
    if [ -n "$(nm -gUj "$WORK_DIR/objects/category-$arch.o")" ]; then
        log_error "Category fixture must not define global symbols ($arch)"
        exit 1
    fi
    xcrun --sdk watchos clang -target "$arch-apple-watchos9.0" -isysroot "$sysroot" \
        -c "$WORK_DIR/empty.c" -o "$WORK_DIR/objects/empty-$arch.o"
done
for fixture in category empty; do
    xcrun lipo -create "$WORK_DIR/objects/$fixture-arm64.o" "$WORK_DIR/objects/$fixture-arm64_32.o" \
        -output "$WORK_DIR/objects/$fixture.o"
done

xcrun --sdk watchos clang -target armv7k-apple-watchos5.0 -isysroot "$sysroot" \
    -c "$WORK_DIR/dependency.c" -o "$WORK_DIR/objects/dependency-armv7k.o"
xcrun lipo -create "$WORK_DIR/objects/target-arm64.o" "$WORK_DIR/objects/target-arm64_32.o" \
    -output "$WORK_DIR/objects/target.o"
xcrun lipo -create "$WORK_DIR/objects/dependency-arm64.o" "$WORK_DIR/objects/dependency-arm64_32.o" \
    -output "$WORK_DIR/objects/dependency-matching.o"
xcrun lipo -create "$WORK_DIR/objects/dependency-matching.o" "$WORK_DIR/objects/dependency-armv7k.o" \
    -output "$WORK_DIR/objects/dependency-extra.o"

# Arguments:
#   name: case directory; missing-*target cases omit the architecture target.
#   dependency: compiled dependency object.
#   expected_error: required log substring on failure; empty means success.
#   target_object: fixture defining the required architecture set.
#   scheme: archived scheme and output library name.
#   architecture_target: target name used for the archived <target>.o file.
#   fault: optional nm/strip failure mode; other cases use the real tools.
run_case() {
    local name="$1" dependency="$2" expected_error="$3"
    local target_object="$4" scheme="$5" architecture_target="$6" fault="${7:-}"
    local root="$WORK_DIR/$name"
    local products="$root/archive/$scheme/watchos.xcarchive/Products/Objects"

    mkdir -p "$products"
    if [[ "$name" != missing-*target ]]; then
        cp "$target_object" "$products/$architecture_target.o"
    fi
    cp "$dependency" "$products/Dependency.o"
    cp "$WORK_DIR/objects/category.o" "$products/Category.o"
    cp "$WORK_DIR/objects/empty.o" "$products/Empty.o"
    if [ "$name" = duplicate-basenames ]; then
        mkdir -p "$products/duplicate"
        cp "$dependency" "$products/duplicate/Dependency.o"
    fi

    local build_products="$root/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath"
    local configuration
    for configuration in Release-watchos Debug-watchos Release-iphoneos; do
        mkdir -p "$build_products/$configuration/Fixture.swiftmodule" "$build_products/$configuration/Fixture.bundle"
        touch "$build_products/$configuration/Fixture.swiftmodule/$configuration"
        touch "$build_products/$configuration/Fixture.bundle/$configuration"
    done

    if [ -n "$fault" ] && [ -n "$expected_error" ]; then
        # A failed rebuild must not leave a previous distribution looking current.
        mkdir -p "$root/lib/$scheme/watchos"
        printf 'stale library\n' > "$root/lib/$scheme/watchos/lib$scheme.a"
    fi

    local status=0
    PATH="$WORK_DIR/tools:$PATH" EXPECTED_SCHEME="$scheme" PACKAGING_FAULT="$fault" \
        REAL_NM="$real_nm" REAL_STRIP="$real_strip" "$SCRIPT_DIR/build-static-library.sh" \
        --sdk watchos \
        --output-dir "$root" \
        --package-path "$WORK_DIR/package" \
        --configuration Release \
        --scheme "$scheme" \
        --architecture-target "$architecture_target" \
        > "$root/build.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$root/build.exit-status"

    if [ -n "$expected_error" ]; then
        if [ "$status" -eq 0 ] || ! grep -Fq "$expected_error" "$root/build.log"; then
            log_error "$name: expected '$expected_error'; see $root/build.log"
            exit 1
        fi
        if [ -e "$root/lib/$scheme/watchos/lib$scheme.a" ]; then
            log_error "$name: invalid archive produced a distributable library"
            exit 1
        fi
        if [ -z "$fault" ] && [ -e "$root/lib/$scheme/watchos/lib$scheme-Debug.a" ]; then
            log_error "$name: invalid archive inputs produced a debug library"
            exit 1
        fi
        if [ -n "$fault" ]; then
            local diagnostic
            if [ "$fault" = strip-noop ]; then
                diagnostic=' OSO '
            else
                diagnostic='injected '
            fi
            if ! grep -F "$diagnostic" "$root/build.log" > /dev/null; then
                log_error "$name: missing tool error or remaining debug-map diagnostic"
                exit 1
            fi
        fi
    else
        if [ "$status" -ne 0 ]; then log_error "$name: packaging failed; see $root/build.log"; exit 1; fi
        local artifact
        for artifact in Swift/Fixture.swiftmodule Resources/Fixture.bundle; do
            local archived="$root/archive/$scheme/watchos.xcarchive/Products/$artifact"
            if [ ! -f "$archived/Release-watchos" ] || \
                [ -e "$archived/Debug-watchos" ] || [ -e "$archived/Release-iphoneos" ]; then
                log_error "$name: $artifact must contain only the selected configuration and platform"
                exit 1
            fi
        done
        local expected_archs
        expected_archs="$(xcrun lipo -archs "$target_object")"
        local expected_arch_array=()
        read -r -a expected_arch_array <<< "$expected_archs"

        for library in "lib$scheme.a" "lib$scheme-Debug.a"; do
            local binary="$root/lib/$scheme/watchos/$library"
            local archs
            archs="$(xcrun lipo -archs "$binary")"

            if [ "$(printf '%s\n' "$archs" | tr ' ' '\n' | sort)" != \
                "$(printf '%s\n' "$expected_archs" | tr ' ' '\n' | sort)" ]; then
                log_error "$name: $library has unexpected architectures: $archs"
                exit 1
            fi

            for arch in "${expected_arch_array[@]}"; do
                local symbols
                symbols="$(nm -arch "$arch" -gUj "$binary" 2> "$root/$library-$arch-nm.log")"
                # These fixtures' exports start with '_'; omit nm's archive-member headings.
                printf '%s\n' "$symbols" | grep '^_' | sort > "$root/$library-$arch-exports.log"
                if ! grep -Fxq '_target_marker' <<< "$symbols" || \
                    ! grep -Fxq '_dependency_marker' <<< "$symbols"; then
                    log_error "$name: $library lost target or dependency content for $arch"
                    exit 1
                fi
                symbols="$(nm -arch "$arch" -ap "$binary" 2>> "$root/$library-$arch-nm.log")"
                if ! grep -F '(Empty.o):' <<< "$symbols" > /dev/null; then
                    log_error "$name: $library lost the symbol-free object ($arch)"
                    exit 1
                fi
                if ! grep -F -- '-[FixtureLogger(FormatString) formatMarker]' <<< "$symbols" > /dev/null; then
                    log_error "$name: $library lost the category without global symbols ($arch)"
                    exit 1
                fi
                if [ "$library" = "lib$scheme.a" ]; then
                    if grep ' OSO ' <<< "$symbols" > /dev/null; then
                        log_error "$name: $library retained external debug maps ($arch)"
                        exit 1
                    fi
                elif ! grep ' OSO ' <<< "$symbols" > /dev/null; then
                    log_error "$name: $library lost the debug maps needed for dynamic dSYMs ($arch)"
                    exit 1
                fi
            done
        done
        for arch in "${expected_arch_array[@]}"; do
            # Stripping debug information must not change the exported symbol set.
            cmp "$root/lib$scheme.a-$arch-exports.log" "$root/lib$scheme-Debug.a-$arch-exports.log"
        done
    fi
    cmp "$dependency" "$products/Dependency.o"
    if [[ "$name" != missing-*target ]]; then cmp "$target_object" "$products/$architecture_target.o"; fi
    log_info "PASS $name"
}

# Ignore the dependency's extra armv7k slice: distribute only the target's
# arm64 and arm64_32 architectures.
run_case \
    extra-dependency-architecture \
    "$WORK_DIR/objects/dependency-extra.o" \
    '' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat

# Preserve both architectures and both objects' symbols when their slices match.
run_case \
    matching-architectures \
    "$WORK_DIR/objects/dependency-matching.o" \
    '' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat

# An arm64-only target must produce an arm64-only library even when its
# dependency also contains arm64_32 and armv7k.
run_case \
    single-target-architecture \
    "$WORK_DIR/objects/dependency-extra.o" \
    '' \
    "$WORK_DIR/objects/target-arm64.o" \
    SentryObjC \
    SentryObjCCompat

# For v9, archive SentrySPM but derive its architectures from SentrySwift,
# excluding the dependency's legacy armv7k slice.
run_case \
    spm-v9 \
    "$WORK_DIR/objects/dependency-extra.o" \
    '' \
    "$WORK_DIR/objects/target.o" \
    SentrySPM \
    SentrySwift

# For v10, use Sentry for both the scheme and architecture target,
# retaining only the target's arm64 slice.
run_case \
    spm-v10 \
    "$WORK_DIR/objects/dependency-extra.o" \
    '' \
    "$WORK_DIR/objects/target-arm64.o" \
    Sentry \
    Sentry

# Reject a dependency missing arm64_32 instead of silently dropping a
# required target architecture.
run_case \
    missing-required-architecture \
    "$WORK_DIR/objects/dependency-arm64.o" \
    'Missing required SentryObjCCompat architecture' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat

# Reject an archive without SentryObjCCompat.o instead of inferring its
# supported architectures from dependencies.
run_case \
    missing-architecture-target \
    "$WORK_DIR/objects/dependency-matching.o" \
    'Expected one archived SentryObjCCompat.o' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat

# Apply the missing-slice check to SentrySwift too: its dependency lacks
# required arm64_32, so neither output library may be produced.
run_case \
    missing-spm-architecture \
    "$WORK_DIR/objects/dependency-arm64.o" \
    'Missing required SentrySwift architecture' \
    "$WORK_DIR/objects/target.o" \
    SentrySPM \
    SentrySwift

# Reject a missing SentrySwift.o even though the SentrySPM archive command
# succeeds and its dependency has both expected architectures.
run_case \
    missing-spm-target \
    "$WORK_DIR/objects/dependency-matching.o" \
    'Expected one archived SentrySwift.o' \
    "$WORK_DIR/objects/target.o" \
    SentrySPM \
    SentrySwift

# Reject duplicate archive member names before merging the input objects.
run_case \
    duplicate-basenames \
    "$WORK_DIR/objects/dependency-matching.o" \
    'Duplicate product object basename: Dependency.o' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat

# Tool failures in a dependency-only architecture must not prevent cleaning the
# supported slices. Reproduces the old pipeline silently skipping the whole object.
run_case \
    unused-architecture-inspection \
    "$WORK_DIR/objects/dependency-extra.o" \
    '' \
    "$WORK_DIR/objects/target.o" \
    SentryObjC \
    SentryObjCCompat \
    unused-architecture

# Fail closed on a required, non-host architecture, preserving the tool's stderr.
for fault in nm-error nm-after-strip-error strip-error strip-noop; do
    case "$fault" in
        nm-*) expected_error='injected nm failure (arm64_32)' ;;
        strip-error) expected_error='injected strip failure' ;;
        strip-noop) expected_error='Static library still contains debug-map references after stripping' ;;
    esac
    run_case \
        "$fault" \
        "$WORK_DIR/objects/dependency-matching.o" \
        "$expected_error" \
        "$WORK_DIR/objects/target.o" \
        SentryObjC \
        SentryObjCCompat \
        "$fault"
done

log_info 'All archive architecture and debug-map regressions passed.'
