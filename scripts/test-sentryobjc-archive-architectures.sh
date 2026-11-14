#!/bin/bash
# Exercise the static-library packager with tiny Mach-O archive products, and the
# shared SDK slice producer's dependency settings and failure propagation.
# Only build commands are stubbed. Fixture compilation, libtool, lipo and nm are real.
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
printf 'int wrapper_marker(void) { return 1; }\n' > "$WORK_DIR/wrapper.c"
printf 'int dependency_marker(void) { return 1; }\n' > "$WORK_DIR/dependency.c"

cat > "$WORK_DIR/tools/xcodebuild" <<'SH'
#!/bin/bash
set -euo pipefail
[ "${1:-}" = -list ] && exit 0
[ "${1:-}" = archive ] || exit 1
echo 'Using precompiled fixture archive products.'
SH
chmod +x "$WORK_DIR/tools/xcodebuild"

sysroot="$(xcrun --sdk watchos --show-sdk-path)"
for arch in arm64 arm64_32; do
    for target in wrapper dependency; do
        xcrun --sdk watchos clang -target "$arch-apple-watchos9.0" -isysroot "$sysroot" \
            -c "$WORK_DIR/$target.c" -o "$WORK_DIR/objects/$target-$arch.o"
    done
done

xcrun --sdk watchos clang -target armv7k-apple-watchos5.0 -isysroot "$sysroot" \
    -c "$WORK_DIR/dependency.c" -o "$WORK_DIR/objects/dependency-armv7k.o"
xcrun lipo -create "$WORK_DIR/objects/wrapper-arm64.o" "$WORK_DIR/objects/wrapper-arm64_32.o" \
    -output "$WORK_DIR/objects/SentryObjCCompat.o"
xcrun lipo -create "$WORK_DIR/objects/dependency-arm64.o" "$WORK_DIR/objects/dependency-arm64_32.o" \
    -output "$WORK_DIR/objects/dependency-matching.o"
xcrun lipo -create "$WORK_DIR/objects/dependency-matching.o" "$WORK_DIR/objects/dependency-armv7k.o" \
    -output "$WORK_DIR/objects/dependency-extra.o"

run_case() {
    local name="$1" dependency="$2" expected_error="$3"
    local wrapper="${4:-$WORK_DIR/objects/SentryObjCCompat.o}"
    local root="$WORK_DIR/$name"
    local products="$root/archive/SentryObjC/watchos.xcarchive/Products/Objects"

    mkdir -p "$products"
    if [ "$name" != missing-wrapper ]; then
        cp "$wrapper" "$products/SentryObjCCompat.o"
    fi
    cp "$dependency" "$products/Dependency.o"

    local status=0
    PATH="$WORK_DIR/tools:$PATH" "$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
        --sdk watchos --output-dir "$root" --package-path "$WORK_DIR/package" \
        > "$root/build.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$root/build.exit-status"

    if [ -n "$expected_error" ]; then
        if [ "$status" -eq 0 ] || ! grep -Fq "$expected_error" "$root/build.log"; then
            log_error "$name: expected '$expected_error'; see $root/build.log"
            exit 1
        fi
        if [ -e "$root/lib/SentryObjC/watchos/libSentryObjC.a" ] || \
            [ -e "$root/lib/SentryObjC/watchos/libSentryObjC-Debug.a" ]; then
            log_error "$name: invalid archive produced a distributable library"
            exit 1
        fi
    else
        if [ "$status" -ne 0 ]; then log_error "$name: packaging failed; see $root/build.log"; exit 1; fi
        local expected_archs
        expected_archs="$(xcrun lipo -archs "$wrapper")"
        local expected_arch_array=()
        read -r -a expected_arch_array <<< "$expected_archs"

        for library in libSentryObjC.a libSentryObjC-Debug.a; do
            local binary="$root/lib/SentryObjC/watchos/$library"
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
                if ! grep -Fxq '_wrapper_marker' <<< "$symbols" || \
                    ! grep -Fxq '_dependency_marker' <<< "$symbols"; then
                    log_error "$name: $library lost wrapper or dependency content for $arch"
                    exit 1
                fi
            done
        done
    fi
    log_info "PASS $name"
}

run_case extra-dependency-architecture "$WORK_DIR/objects/dependency-extra.o" ''
run_case matching-architectures "$WORK_DIR/objects/dependency-matching.o" ''
run_case single-wrapper-architecture "$WORK_DIR/objects/dependency-extra.o" '' "$WORK_DIR/objects/wrapper-arm64.o"
run_case missing-required-architecture "$WORK_DIR/objects/dependency-arm64.o" 'Missing required wrapper architectures'
run_case missing-wrapper "$WORK_DIR/objects/dependency-matching.o" 'Expected one archived SentryObjCCompat.o'

# The shared slice producer must propagate architectures without making package
# object targets dynamic libraries. A successful formatter must not hide build failure.
mkdir -p "$WORK_DIR/producer/tools"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$@"' 'exit 42' > "$WORK_DIR/producer/tools/xcodebuild"
printf '#!/bin/bash\ncat\n' > "$WORK_DIR/producer/tools/xcbeautify"
chmod +x "$WORK_DIR/producer/tools/"*
for sdk in iphoneos maccatalyst iphonesimulator; do
    status=0
    PATH="$WORK_DIR/producer/tools:$PATH" "$SCRIPT_DIR/build-xcframework-slice.sh" \
        --sdk "$sdk" --scheme Sentry --build-path "$WORK_DIR/producer/$sdk" \
        > "$WORK_DIR/producer/$sdk.log" 2>&1 || status=$?
    if [[ "$status" != 42 ]]; then
        log_error "$sdk: expected producer exit 42, got $status; see $WORK_DIR/producer/$sdk.log"
        exit 1
    fi
    expected_archs="ARCHS=\$(ARCHS_STANDARD)"
    if [[ "$sdk" != iphonesimulator ]]; then expected_archs+=' arm64e'; fi
    if ! grep -Fxq "$expected_archs" "$WORK_DIR/producer/$sdk.log" || \
        grep -q '^MACH_O_TYPE=' "$WORK_DIR/producer/$sdk.log"; then
        log_error "$sdk: incorrect package architecture or dynamic-library override"
        exit 1
    fi
    log_info "PASS $sdk producer settings and failure propagation"
done

log_info 'All archive architecture and failure regressions passed.'
