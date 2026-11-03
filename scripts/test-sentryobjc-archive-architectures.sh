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
printf 'int wrapper_marker(void) { return 1; }\n' > "$WORK_DIR/wrapper.c"
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
    local scheme="${5:-SentryObjC}" architecture_target="${6:-SentryObjCCompat}"
    local root="$WORK_DIR/$name"
    local products="$root/archive/$scheme/watchos.xcarchive/Products/Objects"
    local options=()
    if [ $# -ge 5 ]; then
        options+=(--scheme "$scheme" --architecture-target "$architecture_target")
    fi

    mkdir -p "$products"
    if [[ "$name" != missing-*target && "$name" != missing-wrapper ]]; then
        cp "$wrapper" "$products/$architecture_target.o"
    fi
    cp "$dependency" "$products/Dependency.o"

    local status=0
    PATH="$WORK_DIR/tools:$PATH" EXPECTED_SCHEME="$scheme" "$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
        --sdk watchos --output-dir "$root" --package-path "$WORK_DIR/package" \
        ${options[@]+"${options[@]}"} \
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
        local expected_archs
        expected_archs="$(xcrun lipo -archs "$wrapper")"
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
run_case source-v9 "$WORK_DIR/objects/dependency-extra.o" '' "$WORK_DIR/objects/SentryObjCCompat.o" SentrySPM SentrySwift
run_case source-v10-current "$WORK_DIR/objects/dependency-matching.o" '' "$WORK_DIR/objects/SentryObjCCompat.o" Sentry SentrySwift
run_case source-v10-renamed "$WORK_DIR/objects/dependency-extra.o" '' "$WORK_DIR/objects/wrapper-arm64.o" Sentry Sentry
run_case missing-required-architecture "$WORK_DIR/objects/dependency-arm64.o" 'Missing required SentryObjCCompat architecture'
run_case missing-wrapper "$WORK_DIR/objects/dependency-matching.o" 'Expected one archived SentryObjCCompat.o'
run_case missing-source-architecture "$WORK_DIR/objects/dependency-arm64.o" 'Missing required SentrySwift architecture' "$WORK_DIR/objects/SentryObjCCompat.o" SentrySPM SentrySwift
run_case missing-source-target "$WORK_DIR/objects/dependency-matching.o" 'Expected one archived SentrySwift.o' "$WORK_DIR/objects/SentryObjCCompat.o" SentrySPM SentrySwift

for option in --scheme --architecture-target; do
    root="$WORK_DIR/empty-${option#--}"
    if PATH="$WORK_DIR/tools:$PATH" "$SCRIPT_DIR/build-static-library-sentryobjc.sh" \
        --sdk watchos --package-path "$WORK_DIR/package" --output-dir "$root" "$option" '' \
        > "$root.log" 2>&1; then
        log_error "$option: empty value was accepted"
        exit 1
    fi
    grep -Fq 'must not be empty' "$root.log"
    [ ! -d "$root" ]
    log_info "PASS empty-${option#--}"
done

log_info 'All archive architecture regressions passed.'
