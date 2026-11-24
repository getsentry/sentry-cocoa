#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"
archive=""
usage() {
    log_info "Usage: $0 -a|--archive <path to static Sentry framework binary>"
    exit 1
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--archive) archive="${2:?missing archive path}"; shift 2 ;;
        *) usage ;;
    esac
done
[[ -f "$archive" ]] || usage
archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
read -ra archs <<< "$(xcrun lipo -archs "$archive")"
outputs=()
for arch in "${archs[@]}"; do
    dir="$tmp/$arch"
    mkdir "$dir"
    if [[ ${#archs[@]} -gt 1 ]]; then
        xcrun lipo "$archive" -thin "$arch" -output "$dir/sdk.a"
    else
        cp "$archive" "$dir/sdk.a"
    fi
    # Selectors don't create undefined linker symbols. Make loading KSCrash also
    # load its UserInfo category, without requiring consumers to pass -ObjC.
    (
        cd "$dir"
        xcrun ar -x sdk.a KSCrash.o KSCrash+UserInfo.o
        xcrun ld -r -arch "$arch" -o KSCrashWithUserInfo.o KSCrash.o KSCrash+UserInfo.o
        # SwiftPM can contribute the same recording objects more than once. Apple ar -d
        # removes one occurrence per argument; a leftover KSCrash.o can win the final link.
        members=()
        while IFS= read -r member; do
            case "$member" in
                KSCrash.o|KSCrash+UserInfo.o) members+=("$member") ;;
            esac
        done < <(xcrun ar -t sdk.a)
        xcrun ar -d sdk.a "${members[@]}"
        xcrun ar -rs sdk.a KSCrashWithUserInfo.o
    )
    outputs+=("$dir/sdk.a")
done
if [[ ${#outputs[@]} -gt 1 ]]; then
    xcrun lipo -create "${outputs[@]}" -output "$tmp/result.a"
else
    cp "${outputs[0]}" "$tmp/result.a"
fi
# Preserve the framework executable symlink on macOS and Catalyst.
cat "$tmp/result.a" > "$archive"
