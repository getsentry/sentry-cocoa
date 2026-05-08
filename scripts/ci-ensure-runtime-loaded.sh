#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") --os-version <version> --platform <platform>

Ensure a simulator runtime is loaded. CI sometimes fails to load runtimes
automatically; this script unmounts simulator volumes and waits for reload.

OPTIONS:
    --os-version <version>   Runtime version (e.g., 18.2, 26.1)
    --platform <platform>    Platform name (e.g., iOS, tvOS, visionOS)
    -h, --help               Show this help message

EXAMPLES:
    $(basename "$0") --os-version 26.1 --platform iOS
    $(basename "$0") --os-version 16.4 --platform tvOS

EOF
    exit 1
}

OS_VERSION=""
PLATFORM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        --os-version)
            OS_VERSION="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$OS_VERSION" ]; then
    log_error "--os-version argument is required"
    usage
fi

if [ -z "$PLATFORM" ]; then
    log_error "--platform argument is required"
    usage
fi

log_info "Ensuring runtime is loaded:"
log_info "  Platform:   $PLATFORM"
log_info "  OS version: $OS_VERSION"

# Check runtime availability using JSON output. The text-based `simctl list
# runtimes -v` format shows only major.minor in the display name (e.g.
# "iOS 26.4") while hotfix versions like 26.4.1 only appear in parentheses,
# causing simple grep patterns to miss them. JSON is unambiguous.
# visionOS runtimes may report as "xrOS" in older simctl versions.
runtime_is_available() {
    xcrun simctl list runtimes -j 2>/dev/null \
        | jq -e --arg p "$PLATFORM" --arg v "$OS_VERSION" \
            '[.runtimes[]
              | select(.isAvailable == true)
              | select(.platform == $p or ($p == "visionOS" and .platform == "xrOS") or ($p == "xrOS" and .platform == "visionOS"))
              | select(.version == $v)
             ] | length > 0' \
            > /dev/null 2>&1
}

if runtime_is_available; then
    log_info "Runtime $PLATFORM $OS_VERSION is already loaded"
    exit 0
fi

log_info "Runtime $PLATFORM ($OS_VERSION) is not loaded, will try to load it"

begin_group "Unmount simulator volumes"
for dir in /Library/Developer/CoreSimulator/Volumes/*; do
    log_info "Ejecting $dir"
    sudo diskutil unmount force "$dir" || true
done
sudo launchctl kill -9 system/com.apple.CoreSimulator.simdiskimaged || true
sudo pkill -9 com.apple.CoreSimulator.CoreSimulatorService || true
end_group

# Wait for a runtime to be loaded
begin_group "Wait for runtime $PLATFORM ($OS_VERSION)"
count=0
MAX_ATTEMPTS=60 # 300 seconds (5 minutes) timeout
while [ $count -lt $MAX_ATTEMPTS ]; do
    if runtime_is_available; then
        log_info "Runtime $OS_VERSION is loaded after $count attempts"
        end_group
        exit 0
    fi
    log_info "Waiting for runtime $OS_VERSION to be loaded... attempt $count"
    count=$((count + 1))
    sleep 5
done
end_group

log_error "Runtime $PLATFORM ($OS_VERSION) is not loaded after $count attempts"
exit 1
