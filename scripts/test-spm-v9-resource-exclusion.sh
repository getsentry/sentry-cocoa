#!/bin/bash
# The V9 recorder target shares the Sources directory with the SDK's resources. Xcode can
# discover PrivacyInfo.xcprivacy there even when the manifest lists only recorder sources.
# That creates an unintended resource bundle and a generated C accessor whose empty argument
# list fails TestCI's strict-prototype warnings.
#
# The right call here is not to relax warnings or patch the generated code, but to exclude
# the resources from the recorder target.
#
# This build real Xcode package test targets from isolated SDK snapshots for each manifest
# route and requires recorder objects, retained strict warnings, and no recorder
# bundle/accessor. It also exercises Xcode's resource discovery, which swift package describe
# does not expose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

WORK_DIR=""
MANIFEST="all"
PLATFORM="ios"
usage() {
    log_info "Usage: $0 [options]"
    log_info "  -w, --work-dir <path>  Retain snapshots and logs in a new directory (default: temporary)"
    log_info "  -m, --manifest <name>  base, 6.1, 6.2, or all (default: all)"
    log_info "  -p, --platform <name>  ios or macos (default: ios)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--work-dir) WORK_DIR="$2"; shift 2 ;;
        -m|--manifest) MANIFEST="$2"; shift 2 ;;
        -p|--platform) PLATFORM="$2"; shift 2 ;;
        *) usage ;;
    esac
done
case "$MANIFEST" in base|6.1|6.2|all) ;; *) usage ;; esac
case "$PLATFORM" in
    ios) destination="generic/platform=iOS Simulator" ;;
    macos) destination="generic/platform=macOS" ;;
    *) usage ;;
esac

if [[ -z "$WORK_DIR" ]]; then
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT
else
    [[ ! -e "$WORK_DIR" ]] || { log_error "Work directory already exists"; exit 1; }
    mkdir -p "$WORK_DIR"
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
git -C "$REPO_ROOT" archive HEAD --output "$WORK_DIR/source.tar"

manifests=(base 6.1 6.2)
if [[ "$MANIFEST" != all ]]; then manifests=("$MANIFEST"); fi

for manifest in "${manifests[@]}"; do
    root="$WORK_DIR/$manifest"
    sdk="$root/sdk"
    mkdir -p "$sdk"
    tar -xf "$WORK_DIR/source.tar" -C "$sdk"

    # Overlay only the manifests under test, never unrelated working-tree documentation.
    for name in Package.swift Package@swift-6.1.swift Package@swift-6.2.swift; do
        cp "$REPO_ROOT/$name" "$sdk/$name"
    done

    case "$manifest" in
        base) rm "$sdk/Package@swift-6.1.swift" "$sdk/Package@swift-6.2.swift" ;;
        6.1) rm "$sdk/Package@swift-6.2.swift" ;;
    esac
    (
        cd "$sdk"
        ./scripts/prepare-package.sh --remove-binary-targets true > "$root/prepare.log" 2>&1
        status=0

        # Match Distribution Tests V9's TestCI settings; build only, without running tests.
        # Xcode expands $(inherited), not the shell.
        # shellcheck disable=SC2016
        SDK_V10=0 xcodebuild build-for-testing -workspace . -scheme SentrySPM \
            -configuration TestCI -testPlan SentrySPM_Base \
            -destination "$destination" -derivedDataPath "$root/DerivedData" \
            -xcconfig Tests/Configuration/SwiftPM.xcconfig \
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) SENTRY_TEST_CI' \
            'GCC_PREPROCESSOR_DEFINITIONS=$(inherited) DEBUG=1 SENTRY_TEST=1 SENTRY_TEST_CI=1' \
            > "$root/build.log" 2>&1 || status=$?

        printf '%s\n' "$status" > "$root/build.exit-status"

        [[ "$status" == 0 ]] || { log_error "Build failed; see $root/build.log"; exit 1; }
    )

    recorder_objects="$(find "$root/DerivedData" -type f -name SentryCrash.o -print)"
    [[ -n "$recorder_objects" ]] || { log_error "Recorder was not compiled"; exit 1; }

    if find "$root/DerivedData" -path '*SentryCrashV9*.build/*resource_bundle_accessor*' -o \
        -name Sentry_SentryCrashV9.bundle | grep -q .; then
        log_error "Recorder unexpectedly owns a resource bundle/accessor"
        exit 1
    fi

    # The actual recorder compiler invocation must still enable strict prototypes and Werror.
    grep -E -- '-c .*SentryCrash/Recording/SentryCrash\.m ' "$root/build.log" > "$root/recorder-commands.log"
    grep -q -- '-Wstrict-prototypes' "$root/recorder-commands.log"
    grep -q -- '-Werror' "$root/recorder-commands.log"

    if grep -qE -- '-Wno-(error=)?strict-prototypes' "$root/recorder-commands.log"; then
        log_error "Recorder strict-prototype warnings were suppressed"
        exit 1
    fi

    log_info "Passed $manifest/$PLATFORM: recorder compiled with strict warnings and no resource bundle"
done
