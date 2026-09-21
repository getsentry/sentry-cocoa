#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/../../scripts/ci-utils.sh"

REPORT=""
OUTPUT=""
ORG="${SENTRY_ORG:-}"
PROJECT="${SENTRY_PROJECT:-}"
ARCH=""
LOCAL_SYMBOLS=()
DEVICE_SYMBOLS=""
LOCAL_ONLY=false
DEBUG=false
SENTRY_READY=false
CACHE_DIR="$HOME/Library/Caches/io.sentry.tools.metrickit-explorer/dsyms"

usage() {
    cat <<EOF
Usage: $(basename "$0") --report <path-to-json> [OPTIONS]

Find local symbols or download matching Sentry symbols, then use atos to enrich JSON.
Open the result in Utils/MetricKitExplorer/index.html. No server is required.
The input report is never modified. Existing output files are not overwritten.
Requires macOS developer tools, decimal-enabled jq, and sentry-cli for local discovery.
Remote fallback additionally requires authenticated sentry CLI 0.45.0+ and download access.

Options:
    -r, --report <path>       MetricKit JSON report (required)
    -o, --output <path>       Output JSON (default: <report>.symbolicated.json)
    -g, --org <slug>          Organization (default: SENTRY_ORG or CLI default)
    -p, --project <slug>      Project (default: SENTRY_PROJECT or CLI default)
    -a, --arch <name>         Architecture override (default: matching debug file)
    -c, --cache-dir <path>    Downloaded symbol cache (default: $CACHE_DIR)
    -l, --local-symbols <path> Fallback binary, .app, .dSYM, or directory (repeatable)
    -L, --local-only          Use only local symbols, without remote API calls
    -v, --verbose             Log timestamped progress and elapsed time to stderr
    -h, --help                Show this help

Frames without matching or accessible symbols retain their original addresses.
HTTP 403 is a warning. Other API failures stop processing without writing output.
Binary architectures are taken from UUID-matched debug files, not the device architecture.
Local dSYMs are preferred over local binaries. Local files are used in place, not cached.
Report device/OS metadata selects an exact local Xcode iOS device-symbol cache first.
Unmatched images fall back to --local-symbols paths. No broad filesystem search is used.
Without local matches, --local-only leaves frames unresolved.
Without --local-only, unresolved UUIDs fall back to sentry api.
EOF
}

fail() {
    log_error "$1" >&2
    exit 1
}

# Keep diagnostics separate from data. Do not enable shell tracing or either
# CLI's HTTP debug logging, which could expose credentials or response bodies.
debug() {
    if $DEBUG; then
        log_debug "[+${SECONDS}s] $*" >&2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    -L | --local-only)
        LOCAL_ONLY=true
        shift
        ;;
    -v | --verbose)
        DEBUG=true
        shift
        ;;
    -r | --report | -o | --output | -g | --org | -p | --project | -a | --arch | -c | --cache-dir | -l | --local-symbols)
        [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1"
        case "$1" in
        -r | --report) REPORT="$2" ;;
        -o | --output) OUTPUT="$2" ;;
        -g | --org) ORG="$2" ;;
        -p | --project) PROJECT="$2" ;;
        -a | --arch) ARCH="$2" ;;
        -c | --cache-dir) CACHE_DIR="$2" ;;
        -l | --local-symbols) LOCAL_SYMBOLS+=("$2") ;;
        esac
        shift 2
        ;;
    *) fail "Unknown option: $1 (see --help)" ;;
    esac
done

# Fail before network requests if the report cannot be read or the output would
# replace an existing file, including the original report or a symlink to it.
[[ -n "$REPORT" ]] || fail "--report is required (see --help)"
[[ "$REPORT" = /* ]] || REPORT="$PWD/$REPORT"
[[ -f "$REPORT" ]] || fail "Report does not exist: $REPORT"
OUTPUT="${OUTPUT:-${REPORT%.json}.symbolicated.json}"
[[ "$OUTPUT" = /* ]] || OUTPUT="$PWD/$OUTPUT"
[[ "$CACHE_DIR" = /* ]] || CACHE_DIR="$PWD/$CACHE_DIR"
[[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || fail "Output already exists: $OUTPUT"
[[ -d "$(dirname "$OUTPUT")" ]] || fail "Output directory does not exist."

for local_path in ${LOCAL_SYMBOLS[@]+"${LOCAL_SYMBOLS[@]}"}; do
    [[ -e "$local_path" ]] || fail "Local symbols path does not exist: $local_path"
done

for tool in jq xcrun sentry-cli; do
    command -v "$tool" >/dev/null || fail "Required tool not found: $tool"
done

debug "Reading report: $REPORT"
debug "Output: $OUTPUT. Local-only: $LOCAL_ONLY. Architecture: ${ARCH:-infer from symbols}."

# Some MetricKit addresses exceed IEEE-754's exact integer range. Decimal-enabled
# jq preserves their original literals as long as we do not do arithmetic on them.
jq -en 'have_decnum' >/dev/null 2>&1 || fail "jq with decimal-number support is required (for example jq 1.8)."
jq -e '
    (.callStackTree // .).callStacks |
    type == "array" and length > 0 and all(.[];
        type == "object" and (.callStackRootFrames | type == "array") and
        all(.callStackRootFrames[] | recurse(.subFrames[]?);
            type == "object" and (has("subFrames") | not) or
            (type == "object" and (.subFrames | type == "array"))))
' "$REPORT" >/dev/null || fail "Expected a MetricKit call-stack tree, optionally wrapped in callStackTree."

# The report's platformArchitecture describes the device, not every loaded image.
# In particular an arm64e report can contain an arm64 app. Infer each image's
# architecture from its UUID-matched debug file unless explicitly overridden.
case "$ARCH" in
"" | arm64 | arm64e | arm64_32 | x86_64 | i386 | armv7 | armv7s | armv7k) ;;
*) fail "Unsupported --arch (see --help)." ;;
esac

# Defer CLI/authentication requirements until an image actually needs Sentry.
# A fully local report must work even when the sentry executable is not installed.
init_sentry() {
    if $SENTRY_READY; then return; fi
    debug "Initializing sentry CLI for remote fallback."
    command -v sentry >/dev/null || fail "Sentry fallback requires sentry CLI, or use --local-only."
    local version defaults
    version="$(sentry --version)"
    if [[ "$version" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        ((10#${BASH_REMATCH[1]} > 0 || 10#${BASH_REMATCH[2]} >= 45)) ||
            fail "Sentry CLI 0.45.0+ is required for binary downloads and structured HTTP errors."
    else
        fail "Could not determine the Sentry CLI version."
    fi
    if [[ -z "$ORG" || -z "$PROJECT" ]]; then
        debug "Reading sentry CLI organization/project defaults."
        defaults="$(sentry cli defaults --json --fields defaults.organization,defaults.project)"
        ORG="${ORG:-$(printf '%s' "$defaults" | jq -r '.defaults.organization // ""')}"
        PROJECT="${PROJECT:-$(printf '%s' "$defaults" | jq -r '.defaults.project // ""')}"
    fi
    [[ "$ORG" =~ ^[A-Za-z0-9_-]+$ && "$PROJECT" =~ ^[A-Za-z0-9_-]+$ ]] ||
        fail "Specify --org and --project, or configure Sentry CLI defaults."
    ENDPOINT="projects/$ORG/$PROJECT/files/dsyms/"
    debug "Remote project: $ORG/$PROJECT. Download cache: $CACHE_DIR"
    SENTRY_READY=true
}

# Intermediate reports and symbols can contain private function names and paths.
# Temporary downloads are cleaned up on failure, while validated cache files survive.
umask 077
TEMP_DIR="$(mktemp -d "$(dirname "$OUTPUT")/.metrickit-symbols.XXXXXX")"
CACHE_DOWNLOAD=""
cleanup() {
    local status=$?
    rm -rf "$TEMP_DIR"
    if [[ -n "$CACHE_DOWNLOAD" ]]; then rm -f "$CACHE_DOWNLOAD"; fi
    debug "Run finished after ${SECONDS}s (exit $status)."
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Print only the status, never arbitrary error bodies or authenticated URLs.
http_status() {
    jq -r 'objects | .status | numbers' "$1" 2>/dev/null || true
}

api_error() {
    local status
    status="$(http_status "$1")"
    fail "$2${status:+ (HTTP $status)}. Check CLI authentication and debug-file download permissions."
}

# Inspect actual file contents, not just an API response or cache filename.
# Both CLIs call Mach-O files "dsym", including executables with only a symbol table.
validate_symbols() {
    debug "Validating symbols for $binary_uuid ($binary_arch): $1"
    sentry-cli debug-files check --json "$1" >"$TEMP_DIR/checked.json" || fail "Cannot read symbols: $1"
    jq -e --arg uuid "$binary_uuid" --arg arch "$binary_arch" '
        .type == "dsym" and .is_usable and
        any(.variants[]; (.debug_id | ascii_downcase) == $uuid and .arch == $arch)
    ' "$TEMP_DIR/checked.json" >/dev/null ||
        fail "Symbols do not match UUID $binary_uuid and architecture $binary_arch: $1"
}

# Batch the remaining UUIDs rather than scanning the same locations per frame.
# Exit 1 means some UUIDs were not found, but stdout still contains usable matches.
# Accept that only with a valid JSON array, so real CLI errors are not hidden.
find_local_symbols() {
    local id path started status=0
    local ids=()
    jq -r --slurpfile matches "$TEMP_DIR/local-symbols.jsonl" '
        select(.uuid as $id | all($matches[]; .uuid != $id)) | .uuid
    ' "$TEMP_DIR/groups.jsonl" >"$TEMP_DIR/pending-uuids.txt"
    while IFS= read -r id; do ids+=("$id"); done <"$TEMP_DIR/pending-uuids.txt"
    [[ ${#ids[@]} -gt 0 ]] || return 0
    started=$SECONDS
    debug "Starting local discovery for ${#ids[@]} UUIDs using sentry-cli debug-files find."
    sentry-cli debug-files find --no-cwd --no-well-known --type dsym --json "$@" "${ids[@]}" \
        >"$TEMP_DIR/found.json" || status=$?
    debug "Local discovery finished in $((SECONDS - started))s (exit $status, 1 means partial/missing matches)."
    [[ "$status" -le 1 ]] || fail "Local symbol discovery failed (sentry-cli exit $status)."
    jq -e 'type == "array" and all(.[]; .type == "dsym" and (.path | type == "string"))' \
        "$TEMP_DIR/found.json" >/dev/null || fail "Invalid JSON from sentry-cli debug-files find."
    jq -j 'map(.path) | unique[] | ., "\u0000"' "$TEMP_DIR/found.json" >"$TEMP_DIR/found-paths"
    while IFS= read -r -d '' path; do
        debug "Inspecting local symbols: $path"
        sentry-cli debug-files check --json "$path" >"$TEMP_DIR/local-check.json" ||
            fail "Cannot inspect local symbols: $path"
        jq -c --arg path "$path" --arg arch "$ARCH" --rawfile pending "$TEMP_DIR/pending-uuids.txt" '
            select(.type == "dsym" and .is_usable) |
            (.features | split(",") | map(gsub("^ +| +$"; ""))) as $features |
            select(any($features[]; . == "debug" or . == "symtab")) |
            .variants[] | {uuid: (.debug_id | ascii_downcase), arch, path: $path,
                priority: (if $features | index("debug") != null then 0 else 1 end)} |
            select(($arch == "" or .arch == $arch) and (.uuid as $id | ($pending | split("\n") | index($id)) != null))
        ' "$TEMP_DIR/local-check.json" >>"$TEMP_DIR/local-symbols.jsonl"
    done <"$TEMP_DIR/found-paths"
}

# Metadata narrows the cache search, but UUID checks still establish image identity.
# Validate components before constructing a path from an external report. The
# device architecture selects its cache only, never the architecture for atos.
discover_device_symbols() {
    local relative_path path
    relative_path="$(jq -r '
        .diagnosticMetaData? | objects |
        select(.deviceType? | strings | test("^(iPhone|iPad|iPod)[0-9]+,[0-9]+$")) |
        select(.platformArchitecture? | IN("arm64", "arm64e", "armv7", "armv7s")) |
        . as $metadata | .osVersion? | strings |
        capture("^iPhone OS (?<version>[0-9]+(?:\\.[0-9]+)*) \\((?<build>[A-Za-z0-9]+)\\)$") |
        "\($metadata.deviceType) \(.version) (\(.build))/\($metadata.platformArchitecture)/Symbols"
    ' "$REPORT")"
    if [[ -z "$relative_path" ]]; then
        debug "Device metadata is missing or unsupported. Skipping automatic device-symbol discovery."
        return
    fi
    path="$HOME/Library/Developer/Xcode/iOS DeviceSupport/$relative_path"
    debug "Device-symbol cache inferred from report: $relative_path"
    if [[ ! -d "$path" ]]; then
        debug "No matching Xcode device symbols at: $path"
        return
    fi
    debug "Found matching Xcode device symbols: $path"
    DEVICE_SYMBOLS="$path"
}

# Resolve the exact device cache before trying explicit fallbacks. Within those
# fallbacks, prefer dSYM bundles so an app binary cannot mask richer debug info.
# All searches are bounded: no paths means no local symbol matches.
index_local_symbols() {
    local path
    local paths=() dsym_paths=()
    : >"$TEMP_DIR/local-symbols.jsonl"
    : >"$TEMP_DIR/dsym-paths"
    discover_device_symbols
    if [[ -n "$DEVICE_SYMBOLS" ]]; then
        debug "Searching inferred device symbols first: $DEVICE_SYMBOLS"
        find_local_symbols --path "$DEVICE_SYMBOLS"
    fi
    for path in ${LOCAL_SYMBOLS[@]+"${LOCAL_SYMBOLS[@]}"}; do
        [[ "$path" = /* ]] || path="$PWD/$path"
        paths+=(--path "$path")
        if [[ -d "$path" ]]; then
            debug "Scanning local path for dSYM bundles: $path"
            find -H "$path" -type d -name '*.dSYM' -prune -print0 >>"$TEMP_DIR/dsym-paths"
        elif [[ "$path" = *.dSYM/Contents/Resources/DWARF/* ]]; then
            printf '%s\0' "$path" >>"$TEMP_DIR/dsym-paths"
        fi
    done
    while IFS= read -r -d '' path; do dsym_paths+=(--path "$path"); done <"$TEMP_DIR/dsym-paths"
    if [[ ${#paths[@]} -gt 0 ]]; then
        if [[ ${#dsym_paths[@]} -gt 0 ]]; then
            debug "Searching dSYM bundles first ($((${#dsym_paths[@]} / 2)) paths)."
            find_local_symbols "${dsym_paths[@]}"
        fi
        debug "Searching explicit fallback paths (${#LOCAL_SYMBOLS[@]} paths)."
        for path in "${LOCAL_SYMBOLS[@]}"; do debug "Search path: $path"; done
        find_local_symbols "${paths[@]}"
    elif [[ -z "$DEVICE_SYMBOLS" ]]; then
        debug "No device cache or fallback paths available. Leaving local matches unresolved."
    fi
    jq -s 'unique_by([.uuid, .arch, .path])' "$TEMP_DIR/local-symbols.jsonl" >"$TEMP_DIR/local-symbols.json"
    if $DEBUG; then
        debug "Local index contains $(jq 'map(.uuid) | unique | length' "$TEMP_DIR/local-symbols.json") matching images."
    fi
}

# Both resolvers set symbols_file and binary_arch. An empty path means no match.
# Preserve original local paths so atos can find companion Xcode debug information.
resolve_local_symbols() {
    jq --arg uuid "$binary_uuid" --arg arch "$ARCH" '
        map(select(.uuid == $uuid and ($arch == "" or .arch == $arch))) |
        if (map(.arch) | unique | length) > 1 then error("Ambiguous local architecture. Specify --arch.")
        else sort_by(.priority) | first end
    ' "$TEMP_DIR/local-symbols.json" >"$TEMP_DIR/local-match.json"
    symbols_file="$(jq -r '.path // ""' "$TEMP_DIR/local-match.json")"
    if [[ -n "$symbols_file" ]]; then
        binary_arch="$(jq -r '.arch' "$TEMP_DIR/local-match.json")"
        validate_symbols "$symbols_file"
        log_info "Using local symbols for $binary_uuid ($binary_arch): $symbols_file" >&2
    fi
}

# Flatten only the work list, not the report. Group by UUID and deduplicate offsets
# so repeated samples and threads share one lookup and one atos batch per image.
# Offset zero points at a Mach-O header, not executable code. Fractional and unsafe
# numeric offsets cannot be converted reliably and must remain unresolved.
jq -c '
    [(.callStackTree // .).callStacks[].callStackRootFrames[] | recurse(.subFrames[]?) |
        select(.binaryUUID? | type == "string") |
        select(.binaryUUID | test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")) |
        select(.offsetIntoBinaryTextSegment? | type == "number") |
        select(.offsetIntoBinaryTextSegment | . > 0 and . <= 9007199254740991 and . == floor) |
        {uuid: (.binaryUUID | ascii_downcase), offset: .offsetIntoBinaryTextSegment}] |
    group_by(.uuid)[] | {uuid: .[0].uuid, offsets: (map(.offset) | unique)}
' "$REPORT" >"$TEMP_DIR/groups.jsonl"
resolve_sentry_symbols() {
    local file_id started
    init_sentry
    started=$SECONDS
    debug "Looking up uploaded symbols for $binary_uuid using sentry api."
    if ! sentry api "${ENDPOINT}?query=$binary_uuid&per_page=100" --json >"$TEMP_DIR/response.json"; then
        if [[ "$(http_status "$TEMP_DIR/response.json")" = 403 ]]; then
            log_warning "Lookup forbidden for $binary_uuid (HTTP 403). Leaving frames unresolved." >&2
            return
        fi
        api_error "$TEMP_DIR/response.json" "Debug-file lookup failed"
    fi
    debug "Lookup finished in $((SECONDS - started))s for $binary_uuid."

    # Names can repeat across builds, so require an exact UUID match. Prefer DWARF
    # (debug) for source locations over a symbol table, which only provides names.
    # Unwind-only files cannot resolve functions and are deliberately excluded.
    jq --arg uuid "$binary_uuid" --arg arch "$ARCH" '
        .body |
        if type != "array" then error("Expected a debug-file list") else . end |
        map(select((.debugId | ascii_downcase) == $uuid and .symbolType == "macho" and
            ($arch == "" or .cpuName == $arch))) |
        map(select(.cpuName | IN("arm64", "arm64e", "arm64_32", "x86_64", "i386", "armv7", "armv7s", "armv7k"))) |
        map(select(any(.data.features[]; . == "debug" or . == "symtab"))) |
        if (map(.cpuName) | unique | length) > 1 then error("Ambiguous architecture. Specify --arch.")
        else sort_by(.data.features | index("debug") != null) | last end
    ' "$TEMP_DIR/response.json" >"$TEMP_DIR/record.json"
    if [[ "$(jq -r 'type' "$TEMP_DIR/record.json")" = null ]]; then
        log_warning "No uploaded symbols for $binary_uuid${ARCH:+ ($ARCH)}. Leaving frames unresolved." >&2
        return
    fi
    file_id="$(jq -r '.id' "$TEMP_DIR/record.json")"
    [[ "$file_id" =~ ^[0-9]+$ ]] || fail "Sentry returned an invalid debug-file ID."
    binary_arch="$(jq -r '.cpuName' "$TEMP_DIR/record.json")"
    debug "Selected uploaded file $file_id for $binary_uuid ($binary_arch)."

    # The file ID distinguishes separate artifacts for one image, such as a later
    # DWARF upload replacing a symbol-table-only file. Only publish validated bytes.
    symbols_file="$CACHE_DIR/$binary_uuid-$binary_arch-$file_id.macho"
    if [[ ! -e "$symbols_file" ]]; then
        debug "Cache miss: $symbols_file"
        mkdir -p "$CACHE_DIR"
        CACHE_DOWNLOAD="$(mktemp "$CACHE_DIR/.download.XXXXXX")"
        log_info "Downloading symbols for $binary_uuid ($binary_arch)..." >&2
        started=$SECONDS
        if ! sentry api "${ENDPOINT}?id=$file_id" --json >"$CACHE_DOWNLOAD"; then
            # Sentry can allow listing symbols but deny downloading them. Treat
            # that image as unresolved, not as a failure of the entire report.
            if [[ "$(http_status "$CACHE_DOWNLOAD")" = 403 ]]; then
                log_warning "Download forbidden for $binary_uuid (HTTP 403). Leaving frames unresolved." >&2
                rm -f "$CACHE_DOWNLOAD"
                CACHE_DOWNLOAD=""
                symbols_file=""
                return
            fi
            api_error "$CACHE_DOWNLOAD" "Debug-file download failed"
        fi
        debug "Download finished in $((SECONDS - started))s for file $file_id."
        validate_symbols "$CACHE_DOWNLOAD"
        mv -n "$CACHE_DOWNLOAD" "$symbols_file"
        rm -f "$CACHE_DOWNLOAD"
        CACHE_DOWNLOAD=""
        debug "Cached validated symbols: $symbols_file"
    else
        debug "Cache hit: $symbols_file"
        log_info "Using cached symbols for $binary_uuid ($binary_arch)." >&2
    fi
    validate_symbols "$symbols_file"
}

IMAGE_COUNT="$(jq -s 'length' "$TEMP_DIR/groups.jsonl")"
IMAGE_INDEX=0
debug "Prepared $IMAGE_COUNT images with eligible offsets. Starting local symbol discovery."
index_local_symbols
: >"$TEMP_DIR/symbols.jsonl"
while IFS= read -r group; do
    IMAGE_INDEX=$((IMAGE_INDEX + 1))
    binary_uuid="$(printf '%s' "$group" | jq -r '.uuid')"
    debug "Processing image $IMAGE_INDEX/$IMAGE_COUNT: $binary_uuid"
    symbols_file=""
    binary_arch=""
    resolve_local_symbols
    if [[ -z "$symbols_file" ]]; then
        if $LOCAL_ONLY; then
            log_warning "No local symbols for $binary_uuid${ARCH:+ ($ARCH)}. Leaving frames unresolved." >&2
            continue
        fi
        debug "No matching local symbols. Falling back to sentry api for $binary_uuid."
        resolve_sentry_symbols
        [[ -n "$symbols_file" ]] || continue
    fi
    printf '%s' "$group" | jq '.offsets' >"$TEMP_DIR/offsets.json"
    jq -r '.[] | floor' "$TEMP_DIR/offsets.json" >"$TEMP_DIR/offsets-decimal.txt"
    while IFS= read -r offset; do
        printf '0x%x\n' "$offset"
    done <"$TEMP_DIR/offsets-decimal.txt" >"$TEMP_DIR/offsets.txt"

    # ASLR changes absolute addresses. The same UUID can appear with different
    # apparent load addresses in a report, so give atos the per-frame text offsets
    # directly rather than calculating and applying one image-wide slide.
    if $DEBUG; then
        debug "Running atos for $binary_uuid ($binary_arch), $(jq 'length' "$TEMP_DIR/offsets.json") unique offsets."
    fi
    ATOS_STARTED=$SECONDS
    xcrun atos -o "$symbols_file" -arch "$binary_arch" -offset -fullPath \
        -f "$TEMP_DIR/offsets.txt" >"$TEMP_DIR/atos.txt"
    debug "atos finished in $((SECONDS - ATOS_STARTED))s for $binary_uuid."

    # Without -inlineFrames, atos returns one line per requested offset. Keep null
    # entries for unresolved addresses so positional pairing cannot shift frames.
    jq -Rn '[inputs |
        (capture("^(?<function>.+) \\(in .+?\\)(?: \\((?<file>.+):(?<line>[0-9]+)\\)| \\+ [0-9]+)?$") // null) |
        if . == null or .function == "???" or (.function | test("^0x[0-9a-fA-F]+$")) then null
        elif .file != null then {function, file, line: (.line | tonumber)}
        else {function} end
    ]' "$TEMP_DIR/atos.txt" >"$TEMP_DIR/resolved.json"
    if $DEBUG; then
        debug "Resolved $(jq '[.[] | select(. != null)] | length' "$TEMP_DIR/resolved.json") unique offsets for $binary_uuid."
    fi
    jq -n --arg uuid "$binary_uuid" --slurpfile offsets "$TEMP_DIR/offsets.json" \
        --slurpfile resolved "$TEMP_DIR/resolved.json" '
        if ($offsets[0] | length) != ($resolved[0] | length) then
            error("atos returned an unexpected number of frames")
        else {($uuid): ([range(0; $offsets[0] | length) |
            select($resolved[0][.] != null) |
            {key: ($offsets[0][.] | floor | tostring), value: $resolved[0][.]}] | from_entries)} end
    ' >>"$TEMP_DIR/symbols.jsonl"
done <"$TEMP_DIR/groups.jsonl"

# Merge results by UUID and offset, then revisit the original tree. Only add the
# symbolication field to resolved frames. Preserve samples, nesting, metadata,
# original address literals, and every unresolved frame for the HTML viewer.
debug "Enriching report with resolved symbols."
jq -s 'add // {}' "$TEMP_DIR/symbols.jsonl" >"$TEMP_DIR/symbols.json"
jq --slurpfile symbols "$TEMP_DIR/symbols.json" '
    def enrich:
        (if (.binaryUUID | type) == "string" and (.offsetIntoBinaryTextSegment | type) == "number"
            and (.offsetIntoBinaryTextSegment | . > 0 and . <= 9007199254740991 and . == floor)
            then $symbols[0][(.binaryUUID | ascii_downcase)][(.offsetIntoBinaryTextSegment | floor | tostring)]
            else null end) as $symbol |
        (if $symbol != null then .symbolication = $symbol else . end) |
        if has("subFrames") then .subFrames |= map(enrich) else . end;
    def tree: .callStacks |= map(.callStackRootFrames |= map(enrich));
    if has("callStackTree") then .callStackTree |= tree else tree end
' "$REPORT" >"$TEMP_DIR/report.json"
COUNTS="$(jq -r '
    [(.callStackTree // .).callStacks[].callStackRootFrames[] | recurse(.subFrames[]?)] |
    "\(map(select(.symbolication.function? != null)) | length)/\(length)"
' "$TEMP_DIR/report.json")"

# noclobber protects the input and any output created while symbolication was running.
debug "Writing output: $OUTPUT ($COUNTS frames symbolicated)."
(
    set -o noclobber
    cat "$TEMP_DIR/report.json" >"$OUTPUT"
)
log_notice "Symbolicated $COUNTS frames. Wrote $OUTPUT"
