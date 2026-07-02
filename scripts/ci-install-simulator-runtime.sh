#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

PLATFORM=""
OS_VERSION=""

usage() {
    log_notice "Usage: $0"
    log_notice "  --platform <value>      Platform name, e.g. iOS, tvOS (required)"
    log_notice "  --os-version <value>    Runtime version, e.g. 17.5, 18.2 (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)    PLATFORM="$2";    shift 2 ;;
        --os-version)  OS_VERSION="$2";  shift 2 ;;
        *)             usage ;;
    esac
done

if [ -z "$PLATFORM" ]; then
    log_error "Error: --platform is required"
    usage
fi

if [ -z "$OS_VERSION" ]; then
    log_error "Error: --os-version is required"
    usage
fi

if xcrun simctl list runtimes -j 2>/dev/null \
    | jq -e --arg p "$PLATFORM" --arg v "$OS_VERSION" \
        '[.runtimes[] | select(.isAvailable == true) | select(.platform == $p) | select(.version == $v)] | length > 0' \
        > /dev/null 2>&1; then
    log_info "Runtime $PLATFORM $OS_VERSION is already installed"
else
    log_info "Installing $PLATFORM $OS_VERSION runtime..."
    xcodebuild -downloadPlatform "$PLATFORM" -buildVersion "$OS_VERSION"
fi
