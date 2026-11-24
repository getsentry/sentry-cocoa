#!/bin/bash
# Exercise the relinker's arguments without building a shipping SDK variant.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/headers"
echo 'int fixture(void);' > "$work/headers/Fixture.h"
echo 'int fixture(void) { return 1; }' > "$work/fixture.c"
xcrun --sdk macosx clang -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 -g -c "$work/fixture.c" -o "$work/fixture.o"
xcrun libtool -static -o "$work/libFixture.a" "$work/fixture.o"

build_fixture() {
    "$SCRIPT_DIR/build-dynamic-framework.sh" \
        --sdk macosx \
        --framework-name Fixture \
        --version 1.0.0 \
        --static-lib "$work/libFixture.a" \
        --headers "$work/headers" \
        --output-dir "$work" \
        "$@"
}

if build_fixture || build_fixture --archs '' || build_fixture --archs ' '; then
    log_error 'Relinking succeeded without a nonempty --archs list'
    exit 1
fi

if build_fixture --archs 'arm64 arm64e'; then
    log_error 'Relinking succeeded despite the archive lacking arm64e'
    exit 1
fi

for mergeable in false true; do
    build_fixture --archs arm64 --mergeable "$mergeable"

    binary="$work/framework/Fixture/macosx/Fixture.framework/Fixture"
    archs="$(xcrun lipo -archs "$binary")"
    if [[ "$archs" != arm64 ]]; then
        log_error "--archs arm64 produced [$archs]"
        exit 1
    fi
    commands="$(xcrun otool -l "$binary")"
    has_metadata=false
    if grep -q 'cmd LC_ATOM_INFO' <<< "$commands"; then has_metadata=true; fi
    if [[ "$has_metadata" != "$mergeable" ]]; then
        log_error "--mergeable $mergeable produced LC_ATOM_INFO=$has_metadata"
        exit 1
    fi
done
