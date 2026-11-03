#!/usr/bin/env bash
# Generate the main SDK's public API from SwiftPM sources without changing tracked snapshots.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR=""
GENERATION="v9"
SOURCE_PACKAGES=""
KEEP_BUILDS=false

usage() {
    log_info "Usage: $0 --output-dir <path> [options]"
    log_info "  -o, --output-dir <path>      New output directory outside the checkout (required)"
    log_info "  -g, --generation <v9|v10>    SDK generation (default: v9)"
    log_info "  -p, --source-packages <path> Seed from an existing Xcode SourcePackages cache (optional)"
    log_info "  -k, --keep-builds            Retain temporary sources and build products"
    log_info "  -h, --help                   Show this help"
    log_info "Requires Xcode 16; builds arm64 for iOS devices and uses the existing API extractor."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir|-g|--generation|-p|--source-packages)
            if [[ $# -lt 2 || -z "$2" ]]; then
                log_error "Missing value for $1"; exit 2
            fi
            case "$1" in
                -o|--output-dir) OUTPUT_DIR="$2" ;;
                -g|--generation) GENERATION="$2" ;;
                -p|--source-packages) SOURCE_PACKAGES="$2" ;;
            esac
            shift 2 ;;
        -k|--keep-builds) KEEP_BUILDS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

configuration="Release"
scheme="SentrySPM"
api_file="sdk_api.json"
export SDK_V10=0
case "$GENERATION" in
    v9) ;;
    v10) configuration="ReleaseV10"; scheme="Sentry"; api_file="sdk_api_v10.json"; export SDK_V10=1 ;;
    *) log_error "--generation must be v9 or v10"; exit 2 ;;
esac
if [[ -z "$OUTPUT_DIR" || -e "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
    log_error "--output-dir must be a new directory"; exit 2
fi
if [[ -n "$SOURCE_PACKAGES" && ! -d "$SOURCE_PACKAGES" ]]; then
    log_error "--source-packages must be an existing directory"; exit 2
fi
mkdir -p "$(dirname "$OUTPUT_DIR")"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_DIR")" && pwd -P)/$(basename "$OUTPUT_DIR")"
case "$OUTPUT_DIR/" in
    "$REPO_ROOT/"*) log_error "Keep API outputs outside the checkout"; exit 2 ;;
esac
# Match update-api.sh's supported toolchain: newer digesters omit Objective-C API.
xcode_version="$(xcodebuild -version)"
if [[ "$xcode_version" != "Xcode 16."* ]]; then
    log_error "Select Xcode 16 with DEVELOPER_DIR before generating the public API"; exit 1
fi
mkdir -p "$OUTPUT_DIR/logs"
WORK="$(mktemp -d "$OUTPUT_DIR/work.XXXXXX")"
trap 'if ! $KEEP_BUILDS; then rm -rf "$WORK"; fi' EXIT
printf '%s\n' "$xcode_version" > "$OUTPUT_DIR/logs/xcode-version.log"

run_logged() {
    local name="$1"
    shift
    log_info "$name (log: $OUTPUT_DIR/logs/$name.log)"
    # Do not pipe xcodebuild: helper processes can retain the pipe after it exits.
    if "$@" > "$OUTPUT_DIR/logs/$name.log" 2>&1; then
        return 0
    else
        local status=$?
        tail -n 60 "$OUTPUT_DIR/logs/$name.log"
        log_error "$name failed (exit $status)"
        return "$status"
    fi
}

# Include working-tree edits and non-ignored new files, but exclude deleted files.
mkdir "$WORK/package"
git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -z > "$WORK/files"
while IFS= read -r -d '' file; do
    if [[ -f "$REPO_ROOT/$file" || -L "$REPO_ROOT/$file" ]]; then
        printf '%s\0' "$file"
    fi
done < "$WORK/files" | tar -C "$REPO_ROOT" --null -T - -cf - | tar -C "$WORK/package" -xf -
# Use generated source-package schemes, not project/test schemes or released binaries.
rm -rf "$WORK/package/Sentry.xcodeproj" "$WORK/package/Sentry.xcworkspace" "$WORK/package/.swiftpm"
for manifest in "$WORK/package"/Package*.swift; do
    run_logged "prepare-$(basename "$manifest")" "$SCRIPT_DIR/prepare-package.sh" \
        --package-file "$manifest" --remove-binary-targets true
done
if [[ -n "$SOURCE_PACKAGES" ]]; then
    cp -R "$SOURCE_PACKAGES" "$WORK/packages"
fi
run_logged resolve xcodebuild -list -workspace "$WORK/package" \
    -clonedSourcePackagesDirPath "$WORK/packages" -skipPackageUpdates

# Xcode 16's interface verifier needs the generated Clang map on Swift search paths.
mkdir -p "$WORK/header-search"
ln -s "$WORK/build/Build/Intermediates.noindex/GeneratedModuleMaps-iphoneos/SentryHeaders.modulemap" \
    "$WORK/header-search/module.modulemap"
run_logged build xcodebuild build -workspace "$WORK/package" -scheme "$scheme" \
    -configuration "$configuration" -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "$WORK/build" -clonedSourcePackagesDirPath "$WORK/packages" -skipPackageUpdates \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO ENABLE_CODE_COVERAGE=NO \
    "SWIFT_INCLUDE_PATHS=\$(inherited) \"$WORK/header-search\" \"$WORK/package/Sources/Sentry/Public\""

# Extract public text interfaces from disposable copies, not serialized modules with
# saved build-time search paths. Leave the original build products intact.
mkdir "$WORK/api"
cp -R "$WORK/build/Build/Products/$configuration-iphoneos/SentrySwift.swiftmodule" "$WORK/api/"
cp "$WORK/build/Build/Intermediates.noindex/GeneratedModuleMaps-iphoneos/SentryHeaders.modulemap" \
    "$WORK/api/module.modulemap"
find "$WORK/api" -type f \( -name '*.private.swiftinterface' -o -name '*.package.swiftinterface' \
    -o -name '*.swiftmodule' \) -delete
include_args=(--include-path "$WORK/api" --include-path "$WORK/package/Sources/Sentry/Public"
    --include-path "$WORK/package/Sources/Sentry/include")
if [[ "$GENERATION" == "v10" ]]; then
    include_args+=(--include-path "$WORK/package/Sources/SentryV10Configuration/include")
else
    include_args+=(--include-path "$WORK/package/Sources/SentryCrashV9Headers/include")
fi
run_logged extract "$SCRIPT_DIR/extract-swift-api.sh" --module SentrySwift --module SentryHeaders \
    --output "$OUTPUT_DIR/$api_file" --raw-output "$OUTPUT_DIR/${api_file%.json}.raw.json" \
    "${include_args[@]}"
if ! jq -e 'any(.ABIRoot.children[]; .name == "SentrySDK") and
            any(.ABIRoot.children[]; .name == "Options")' "$OUTPUT_DIR/$api_file" > /dev/null; then
    log_error "Extraction is missing expected SDK declarations"; exit 1
fi
log_info "SwiftPM API dump: $OUTPUT_DIR/$api_file"
