#!/usr/bin/env bash
# Generate raw V9 public API dumps through Xcode, SwiftPM, or both build systems.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

BUILD_SYSTEM=""
OUTPUT_DIR=""
SOURCE_PACKAGES=""
KEEP_BUILDS=false

usage() {
    log_info "Usage: $0 --build-system <xcode|spm|both> --output-dir <path> [options]"
    log_info "  -b, --build-system <name>   Build system: xcode, spm, or both (required)"
    log_info "  -o, --output-dir <path>     New output directory outside the checkout (required)"
    log_info "  -p, --source-packages <path> Seed builds from an existing Xcode SourcePackages cache"
    log_info "  -k, --keep-builds           Retain temporary sources and build products (default: false)"
    log_info "  -h, --help                  Show this help"
    log_info "Uses the selected Xcode, V9 Release, arm64 iOS Simulator; no simulator is booted."
    log_info "Writes raw *-public.json dumps, module lists, context, and logs; does not compare APIs."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build-system|-o|--output-dir|-p|--source-packages)
            if [[ $# -lt 2 || -z "$2" ]]; then
                log_error "Missing value for $1"
                exit 2
            fi
            case "$1" in
                -b|--build-system) BUILD_SYSTEM="$2" ;;
                -o|--output-dir) OUTPUT_DIR="$2" ;;
                -p|--source-packages) SOURCE_PACKAGES="$2" ;;
            esac
            shift 2 ;;
        -k|--keep-builds) KEEP_BUILDS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

case "$BUILD_SYSTEM" in
    xcode|spm|both) ;;
    *) log_error "--build-system must be xcode, spm, or both"; exit 2 ;;
esac
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
    "$REPO_ROOT/"*) log_error "Keep API outputs outside the checkout"; exit 2 ;;
esac
mkdir "$OUTPUT_DIR"
mkdir "$OUTPUT_DIR/logs"
WORK="$(mktemp -d "$OUTPUT_DIR/work.XXXXXX")"
trap 'if ! $KEEP_BUILDS; then rm -rf "$WORK"; fi' EXIT

# Generate the default V9 product, regardless of local development selection.
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
        log_error "$name failed (exit $status); API generation did not complete"
        return "$status"
    fi
}

begin_group "Prepare source snapshot"
# Include edits and non-ignored new files, but not derived data or deleted files.
# In both mode, the two builders consume the same snapshot, never a released binary.
mkdir "$WORK/source"
git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -z > "$WORK/files"
while IFS= read -r -d '' file; do
    if [[ -f "$REPO_ROOT/$file" || -L "$REPO_ROOT/$file" ]]; then
        printf '%s\0' "$file"
    fi
done < "$WORK/files" | tar -C "$REPO_ROOT" --null -T - -cf - | tar -C "$WORK/source" -xf -
if [[ "$BUILD_SYSTEM" != "xcode" ]]; then
    cp -R "$WORK/source" "$WORK/package"
    # Select generated package schemes, never the repository's project or test scheme.
    rm -rf "$WORK/package/Sentry.xcodeproj" "$WORK/package/Sentry.xcworkspace" "$WORK/package/.swiftpm"
    for manifest in "$WORK/package"/Package*.swift; do
        run_logged "prepare-$(basename "$manifest")" "$SCRIPT_DIR/prepare-package.sh" \
            --package-file "$manifest" --remove-binary-targets true
    done
    # Retain versioned manifests so SwiftPM selects the one supported by this toolchain.
fi
if [[ -n "$SOURCE_PACKAGES" ]]; then
    cp -R "$SOURCE_PACKAGES" "$WORK/packages"
fi
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
jq -n --arg revision "$(git -C "$REPO_ROOT" rev-parse HEAD)" \
    --arg working_tree "$(git -C "$REPO_ROOT" status --short)" \
    --arg xcode "$(xcodebuild -version)" --arg swift "$(xcrun swiftc --version)" \
    --arg sdk "$sdk_path" --arg build_system "$BUILD_SYSTEM" \
    '{revision:$revision, workingTree:$working_tree, xcode:$xcode, swift:$swift, sdk:$sdk,
      buildSystem:$build_system, target:"arm64-apple-ios15.0-simulator",
      configuration:"Release", generation:"V9"}' > "$OUTPUT_DIR/context.json"
end_group

build_args=(
    -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'
    -clonedSourcePackagesDirPath "$WORK/packages" -skipPackageUpdates
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    CODE_SIGNING_ALLOWED=NO ENABLE_CODE_COVERAGE=NO
)
begin_group "Build public interfaces"
if [[ "$BUILD_SYSTEM" != "spm" ]]; then
    run_logged build-xcode xcodebuild build -project "$WORK/source/Sentry.xcodeproj" \
        -scheme Sentry -derivedDataPath "$WORK/xcode" "${build_args[@]}"
fi
if [[ "$BUILD_SYSTEM" != "xcode" ]]; then
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
fi
end_group

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
        # Collect transitive header submodules, otherwise the comparison invents missing API.
        {
            cat "$modules"
            jq -r --arg prefix "$header_module." \
                '.ABIRoot.children[] | select(.kind == "Import" and (.name | startswith($prefix))) | .name' \
                "$dump"
        } | sort -u > "$modules.next"
        if cmp -s "$modules" "$modules.next"; then
            rm "$modules.next"
            # Guard against empty or accidentally wrong-module extractions.
            if ! jq -e 'any(.ABIRoot.children[]; .name == "SentrySDK") and
                        any(.ABIRoot.children[]; .name == "Options")' "$dump" > /dev/null; then
                log_error "$label extraction is missing expected SDK declarations"
                return 1
            fi
            return 0
        fi
        mv "$modules.next" "$modules"
    done
    log_error "Header module discovery did not converge for $label"
    return 1
}

begin_group "Extract public interfaces"
# Only strip private interfaces from disposable API copies, not the build products.
if [[ "$BUILD_SYSTEM" != "spm" ]]; then
    mkdir -p "$WORK/api/xcode"
    cp -R "$WORK/xcode/Build/Products/Release-iphonesimulator/Sentry.framework" "$WORK/api/xcode/"
    find "$WORK/api/xcode" -name '*.private.swiftinterface' -type f -delete
    extract_api xcode Sentry Sentry -F "$WORK/api/xcode"
fi
if [[ "$BUILD_SYSTEM" != "xcode" ]]; then
    mkdir -p "$WORK/api/spm"
    cp -R "$WORK/spm/Build/Products/Release-iphonesimulator/SentrySwift.swiftmodule" "$WORK/api/spm/"
    cp "$WORK/spm/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/SentryHeaders.modulemap" \
        "$WORK/api/spm/module.modulemap"
    find "$WORK/api/spm" -name '*.private.swiftinterface' -type f -delete
    extract_api spm SentrySwift SentryHeaders -I "$WORK/api/spm" \
        -I "$WORK/package/Sources/Sentry/Public" -I "$WORK/package/Sources/Sentry/include" \
        -I "$WORK/package/Sources/SentryCrashV9Headers/include"
fi
end_group
log_info "API dumps: $OUTPUT_DIR"
