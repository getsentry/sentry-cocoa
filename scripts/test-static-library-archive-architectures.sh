#!/bin/bash
# Exercise the real static-library packager with tiny Mach-O archive products.
# Only xcodebuild is stubbed! Compilation, libtool, lipo and nm are real.
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
printf 'int target_marker(void) { return 1; }\n' > "$WORK_DIR/target.c"
printf 'int dependency_marker(void) { return 1; }\n' > "$WORK_DIR/dependency.c"

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
chmod +x "$WORK_DIR/tools/xcodebuild"

sysroot="$(xcrun --sdk watchos --show-sdk-path)"
for arch in arm64 arm64_32; do
    for fixture in target dependency; do
        xcrun --sdk watchos clang -target "$arch-apple-watchos9.0" -isysroot "$sysroot" \
            -c "$WORK_DIR/$fixture.c" -o "$WORK_DIR/objects/$fixture-$arch.o"
    done
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
run_case() {
    local name="$1" dependency="$2" expected_error="$3"
    local target_object="$4" scheme="$5" architecture_target="$6"
    local root="$WORK_DIR/$name"
    local products="$root/archive/$scheme/watchos.xcarchive/Products/Objects"

    mkdir -p "$products"
    if [[ "$name" != missing-*target ]]; then
        cp "$target_object" "$products/$architecture_target.o"
    fi
    cp "$dependency" "$products/Dependency.o"

    local build_products="$root/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/$scheme/BuildProductsPath"
    local configuration
    for configuration in Release-watchos Debug-watchos Release-iphoneos; do
        mkdir -p "$build_products/$configuration/Fixture.swiftmodule" "$build_products/$configuration/Fixture.bundle"
        touch "$build_products/$configuration/Fixture.swiftmodule/$configuration"
        touch "$build_products/$configuration/Fixture.bundle/$configuration"
    done

    local status=0
    PATH="$WORK_DIR/tools:$PATH" EXPECTED_SCHEME="$scheme" "$SCRIPT_DIR/build-static-library.sh" \
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
        if [ -e "$root/lib/$scheme/watchos/lib$scheme.a" ] || \
            [ -e "$root/lib/$scheme/watchos/lib$scheme-Debug.a" ]; then
            log_error "$name: invalid archive produced a distributable library"
            exit 1
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
                symbols="$(nm -arch "$arch" -gUj "$binary")"
                if ! grep -Fxq '_target_marker' <<< "$symbols" || \
                    ! grep -Fxq '_dependency_marker' <<< "$symbols"; then
                    log_error "$name: $library lost target or dependency content for $arch"
                    exit 1
                fi
            done
        done
    fi
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

log_info 'All archive architecture regressions passed.'
