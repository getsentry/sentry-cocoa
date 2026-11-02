#!/usr/bin/env bash
# Build the V9 framework and source package, then report public source-API differences.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

OUTPUT_DIR=""
SOURCE_PACKAGES=""
KEEP_BUILDS=false

usage() {
    log_info "Usage: $0 --output-dir <path> [options]"
    log_info "  -o, --output-dir <path>      New report directory outside the checkout (required)"
    log_info "  -p, --source-packages <path> Seed builds from an existing Xcode SourcePackages cache"
    log_info "  -k, --keep-builds            Retain temporary sources and build products (default: false)"
    log_info "  -h, --help                   Show this help"
    log_info "Uses the selected Xcode, V9 Release, arm64 iOS Simulator; no simulator is booted."
    log_info "API differences are informational; build/extraction errors return nonzero."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir|-p|--source-packages)
            if [[ $# -lt 2 || -z "$2" ]]; then
                log_error "Missing value for $1"
                exit 2
            fi
            case "$1" in
                -o|--output-dir) OUTPUT_DIR="$2" ;;
                -p|--source-packages) SOURCE_PACKAGES="$2" ;;
            esac
            shift 2 ;;
        -k|--keep-builds) KEEP_BUILDS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

if [[ -z "$OUTPUT_DIR" || -e "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
    log_error "--output-dir must be a new directory"
    exit 2
fi
if [[ -n "$SOURCE_PACKAGES" && ! -d "$SOURCE_PACKAGES" ]]; then
    log_error "--source-packages must be an existing directory"
    exit 2
fi
mkdir -p "$(dirname "$OUTPUT_DIR")"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
case "$OUTPUT_DIR/" in
    "$REPO_ROOT/"*) log_error "Keep parity outputs outside the checkout"; exit 2 ;;
esac
mkdir "$OUTPUT_DIR"
mkdir "$OUTPUT_DIR/logs"
WORK="$(mktemp -d "$OUTPUT_DIR/work.XXXXXX")"
trap 'if ! $KEEP_BUILDS; then rm -rf "$WORK"; fi' EXIT

# This job compares the default V9 product, regardless of local development selection.
export SDK_V10=0

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
        log_error "$name failed (exit $status); no API parity conclusion is available"
        return "$status"
    fi
}

begin_group "Prepare matching source snapshots"
# Copy the current working tree, including edits and non-ignored new files, but not
# derived data. Both builders use the same snapshot, not a downloaded SDK binary.
mkdir "$WORK/source"
git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -z > "$WORK/files"
while IFS= read -r -d '' file; do
    if [[ -f "$REPO_ROOT/$file" || -L "$REPO_ROOT/$file" ]]; then
        printf '%s\0' "$file"
    fi
done < "$WORK/files" | tar -C "$REPO_ROOT" --null -T - -cf - | tar -C "$WORK/source" -xf -
cp -R "$WORK/source" "$WORK/package"
# Select generated package schemes, never the repository's Xcode project or test scheme.
rm -rf "$WORK/package/Sentry.xcodeproj" "$WORK/package/Sentry.xcworkspace" "$WORK/package/.swiftpm"
for manifest in "$WORK/package"/Package*.swift; do
    run_logged "prepare-$(basename "$manifest")" "$SCRIPT_DIR/prepare-package.sh" \
        --package-file "$manifest" --remove-binary-targets true
done
# Retain every versioned manifest: SwiftPM chooses the one supported by this toolchain.
if [[ -n "$SOURCE_PACKAGES" ]]; then
    cp -R "$SOURCE_PACKAGES" "$WORK/packages"
fi
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
jq -n --arg revision "$(git -C "$REPO_ROOT" rev-parse HEAD)" \
    --arg working_tree "$(git -C "$REPO_ROOT" status --short)" \
    --arg xcode "$(xcodebuild -version)" --arg swift "$(xcrun swiftc --version)" \
    --arg sdk "$sdk_path" \
    '{revision:$revision, workingTree:$working_tree, xcode:$xcode, swift:$swift, sdk:$sdk,
      target:"arm64-apple-ios15.0-simulator", configuration:"Release", generation:"V9"}' \
    > "$OUTPUT_DIR/context.json"
end_group

build_args=(
    -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'
    -clonedSourcePackagesDirPath "$WORK/packages" -skipPackageUpdates
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    CODE_SIGNING_ALLOWED=NO ENABLE_CODE_COVERAGE=NO
)
begin_group "Build Xcode and SwiftPM APIs"
run_logged build-xcode xcodebuild build -project "$WORK/source/Sentry.xcodeproj" \
    -scheme Sentry -derivedDataPath "$WORK/xcode" "${build_args[@]}"
# Resolve first: Xcode can regenerate package schemes during the first checkout.
run_logged resolve-spm xcodebuild -list -workspace "$WORK/package" \
    -clonedSourcePackagesDirPath "$WORK/packages" -skipPackageUpdates
# Xcode 16's interface verifier needs transitive Clang dependencies discoverable
# through Swift search paths, not just the package's -Xcc module-map arguments.
# Reuse the generated map and original public headers; keep verification enabled.
mkdir -p "$WORK/api/header-search"
ln -s "$WORK/spm/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/SentryHeaders.modulemap" \
    "$WORK/api/header-search/module.modulemap"
run_logged build-spm xcodebuild build -workspace "$WORK/package" -scheme SentrySPM \
    -derivedDataPath "$WORK/spm" "${build_args[@]}" \
    "SWIFT_INCLUDE_PATHS=\$(inherited) \"$WORK/api/header-search\" \"$WORK/package/Sources/Sentry/Public\""
end_group

begin_group "Extract public interfaces"
mkdir -p "$WORK/api/xcode" "$WORK/api/spm"
cp -R "$WORK/xcode/Build/Products/Release-iphonesimulator/Sentry.framework" "$WORK/api/xcode/"
cp -R "$WORK/spm/Build/Products/Release-iphonesimulator/SentrySwift.swiftmodule" "$WORK/api/spm/"
cp "$WORK/spm/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/SentryHeaders.modulemap" \
    "$WORK/api/spm/module.modulemap"
# Only modify disposable copies; never strip interfaces from a distributable framework.
find "$WORK/api" -name '*.private.swiftinterface' -type f -delete

extract_api() {
    local label="$1" swift_module="$2" header_module="$3"
    shift 3
    local modules="$OUTPUT_DIR/$label-modules.txt"
    local dump="$OUTPUT_DIR/$label-public.json"
    local round
    printf '%s\n' "$swift_module" "$header_module" | sort -u > "$modules"
    for ((round=1; round<=64; round++)); do
        run_logged "extract-$label-$round" xcrun --sdk iphonesimulator swift-api-digester \
            -dump-sdk -o "$dump" -abort-on-module-fail -avoid-tool-args -avoid-location \
            -module-list-file "$modules" -use-interface-for-module "$swift_module" \
            -target arm64-apple-ios15.0-simulator -sdk "$sdk_path" \
            -module-cache-path "$WORK/api/cache-$label" "$@"
        # Header submodules can import further submodules (e.g. profiling conditionals).
        # Collect their transitive closure, otherwise the comparison invents missing API.
        {
            cat "$modules"
            jq -r --arg prefix "$header_module." \
                '.ABIRoot.children[] | select(.kind == "Import" and (.name | startswith($prefix))) | .name' \
                "$dump"
        } | sort -u > "$modules.next"
        if cmp -s "$modules" "$modules.next"; then
            rm "$modules.next"
            # Guard against empty or accidentally wrong-module extractions.
            jq -e 'any(.ABIRoot.children[]; .name == "SentrySDK") and
                   any(.ABIRoot.children[]; .name == "Options")' "$dump" > /dev/null
            return 0
        fi
        mv "$modules.next" "$modules"
    done
    log_error "Header module discovery did not converge for $label"
    return 1
}

extract_api xcode Sentry Sentry -F "$WORK/api/xcode"
extract_api spm SentrySwift SentryHeaders -I "$WORK/api/spm" \
    -I "$WORK/package/Sources/Sentry/Public" -I "$WORK/package/Sources/Sentry/include" \
    -I "$WORK/package/Sources/SentryCrashV9Headers/include"
end_group

begin_group "Report API parity"
status=0
python3 "$SCRIPT_DIR/compare-public-api.py" \
    --baseline "$OUTPUT_DIR/xcode-public.json" --candidate "$OUTPUT_DIR/spm-public.json" \
    --output-dir "$OUTPUT_DIR/report" || status=$?
case "$status" in
    0) log_info "The compared source APIs match" ;;
    1) log_warning "Xcode and SwiftPM expose different source APIs; see the informational report" ;;
    *) log_error "API comparison failed (exit $status)"; exit "$status" ;;
esac
log_info "Report: $OUTPUT_DIR/report/summary.md"
end_group
