#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./ci-utils.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

ACTION=""
DEVICE=""
SDK_GENERATION="9"
STANDALONE="false"
BUILD_LABEL=""
DEVELOPER_DIR_VALUE=""
CONFIGURATION="Debug"
DEVELOPMENT_TEAM=""
DSN=""
OUTPUT="$REPO_ROOT/.build/os-27-prewarm/results"
INPUT=""
SUSPEND_SECONDS="15"

usage() {
    log_notice "Usage: $0 --action <devices|generate|install|simulate-prewarm|collect|summarize> [options]"
    log_notice "  --device <name-or-id>       Physical device for install/collect"
    log_notice "  --sdk-generation <9|10>     SDK generation to build (default: 9)"
    log_notice "  --standalone <true|false>   V9 standalone tracing mode (default: false; V10 is always standalone)"
    log_notice "  --build-label <label>       Label embedded in each report"
    log_notice "  --developer-dir <path>      Xcode Developer directory (default: Xcode-beta when available)"
    log_notice "  --configuration <name>      Xcode configuration (default: Debug)"
    log_notice "  --development-team <id>     Override signing with automatic signing for this team"
    log_notice "  --dsn <dsn>                 Override the sample Sentry DSN"
    log_notice "  --output <path>             Collection destination root"
    log_notice "  --input <path>              Report directory for summarize"
    log_notice "  --suspend-seconds <number>  Simulated prewarm suspension (default: 15)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --action) ACTION="$2"; shift 2 ;;
        --device) DEVICE="$2"; shift 2 ;;
        --sdk-generation) SDK_GENERATION="$2"; shift 2 ;;
        --standalone) STANDALONE="$2"; shift 2 ;;
        --build-label) BUILD_LABEL="$2"; shift 2 ;;
        --developer-dir) DEVELOPER_DIR_VALUE="$2"; shift 2 ;;
        --configuration) CONFIGURATION="$2"; shift 2 ;;
        --development-team) DEVELOPMENT_TEAM="$2"; shift 2 ;;
        --dsn) DSN="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --input) INPUT="$2"; shift 2 ;;
        --suspend-seconds) SUSPEND_SECONDS="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    log_error "--action is required"
    usage
fi

if [[ -z "$DEVELOPER_DIR_VALUE" ]]; then
    if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
        DEVELOPER_DIR_VALUE="/Applications/Xcode-beta.app/Contents/Developer"
    else
        DEVELOPER_DIR_VALUE="$(xcode-select -p)"
    fi
fi

if [[ ! -d "$DEVELOPER_DIR_VALUE" ]]; then
    log_error "Developer directory does not exist: $DEVELOPER_DIR_VALUE"
    exit 1
fi

if [[ "$SDK_GENERATION" != "9" && "$SDK_GENERATION" != "10" ]]; then
    log_error "--sdk-generation must be 9 or 10"
    exit 1
fi

if [[ "$STANDALONE" != "true" && "$STANDALONE" != "false" ]]; then
    log_error "--standalone must be true or false"
    exit 1
fi

if [[ ! "$SUSPEND_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    log_error "--suspend-seconds must be a positive integer"
    exit 1
fi

if [[ "$SDK_GENERATION" == "10" ]]; then
    STANDALONE="true"
fi

require_device() {
    if [[ -z "$DEVICE" ]]; then
        log_error "--device is required for action '$ACTION'"
        usage
    fi
}

list_devices() {
    local json_file
    json_file="$(mktemp)"
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl list devices --json-output "$json_file" >/dev/null
    jq -r '
        ["NAME", "PLATFORM", "OS", "IDENTIFIER"],
        (.result.devices[] |
            [
                .deviceProperties.name,
                .hardwareProperties.platform,
                .deviceProperties.osVersionNumber,
                .identifier
            ]) |
        @tsv
    ' "$json_file"
    rm -f "$json_file"
}

generate_project() {
    make -C "$REPO_ROOT" xcode-ci-OS27-Prewarm
}

install_app() {
    require_device
    generate_project

    local scheme="OS27-Prewarm-V$SDK_GENERATION"
    local standalone_setting="NO"
    if [[ "$STANDALONE" == "true" ]]; then
        standalone_setting="YES"
    fi

    if [[ -z "$BUILD_LABEL" ]]; then
        local xcode_version
        xcode_version="$(DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcodebuild -version | head -n 1 | tr ' ' '-')"
        BUILD_LABEL="${xcode_version}-v${SDK_GENERATION}-$([[ "$STANDALONE" == "true" ]] && echo standalone || echo attached)"
    fi

    local safe_label
    safe_label="$(printf '%s' "$BUILD_LABEL" | tr -c '[:alnum:]_-' '-')"
    local derived_data="$REPO_ROOT/.build/os-27-prewarm/derived/$safe_label"
    local build_log="$derived_data/build.log"
    mkdir -p "$derived_data"

    local build_args=(
        -project "$REPO_ROOT/Samples/OS27-Prewarm/OS27-Prewarm.xcodeproj"
        -scheme "$scheme"
        -configuration "$CONFIGURATION"
        -destination "generic/platform=iOS"
        -derivedDataPath "$derived_data"
        -allowProvisioningUpdates
        -allowProvisioningDeviceRegistration
        "ARCHS=arm64"
        "OS27_PREWARM_BUILD_LABEL=$BUILD_LABEL"
        "OS27_PREWARM_STANDALONE=$standalone_setting"
    )

    if [[ -n "$DEVELOPMENT_TEAM" ]]; then
        build_args+=(
            "CODE_SIGN_STYLE=Automatic"
            "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
            "PROVISIONING_PROFILE_SPECIFIER="
        )
    fi
    if [[ -n "$DSN" ]]; then
        build_args+=("OS27_PREWARM_DSN=$DSN")
    fi

    log_notice "Building $scheme with $BUILD_LABEL"
    set +e
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcodebuild "${build_args[@]}" >"$build_log" 2>&1
    local build_status=$?
    set -e
    grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" "$build_log" || true
    if [[ $build_status -ne 0 ]]; then
        log_error "Build failed. Full output: $build_log"
        exit "$build_status"
    fi

    local app_path="$derived_data/Build/Products/$CONFIGURATION-iphoneos/OS27-Prewarm.app"
    if [[ ! -d "$app_path" ]]; then
        log_error "Built app not found: $app_path"
        exit 1
    fi

    log_notice "Installing without launching on $DEVICE"
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl device install app \
        --device "$DEVICE" \
        "$app_path"

    log_notice "Installed $BUILD_LABEL. Disconnect the debugger and launch OS27-Prewarm from the Home Screen."
}

summarize_reports() {
    local source="$INPUT"
    if [[ -z "$source" ]]; then
        source="$OUTPUT"
    fi
    if [[ ! -d "$source" ]]; then
        log_error "Report directory does not exist: $source"
        exit 1
    fi

    printf 'BUILD\tSDK\tSTANDALONE\tPREWARM\tDEBUGGER\tPROCESS→MAIN MS\tPROCESS→DID FINISH MS\tPROCESS→DISPLAY LINK MS\tSENTRY\tFILE\n'
    find "$source" -type f -name 'launch-*.json' -print | sort | while IFS= read -r report; do
        jq -r --arg file "$report" '
            def transaction_summaries:
                [
                    .sentryTransactions[]?.serialized |
                    {
                        name: .transaction,
                        operation: .contexts.trace.op,
                        startType: (.extra["app.vitals.start.type"] // .contexts.app.start_type),
                        prewarmed: (
                            if (.extra | type) == "object" and (.extra | has("app.vitals.start.prewarmed"))
                            then .extra["app.vitals.start.prewarmed"]
                            else null
                            end
                        ),
                        durationMs: (
                            .extra["app.vitals.start.value"] //
                            .measurements.app_start_cold.value //
                            .measurements.app_start_warm.value
                        )
                    }
                ] | map(select(((.operation // "") | startswith("app.start")) or .startType != null));
            def span_summaries:
                [
                    .sentrySpans[]? |
                    {
                        name: "span",
                        operation: .operation,
                        startType: .data["app.vitals.start.type"],
                        prewarmed: .data["app.vitals.start.prewarmed"],
                        durationMs: .durationMs
                    }
                ] | map(select((.operation // "") | startswith("app.start")));
            def measurement_summary:
                if .sentryAppStartMeasurement == null then []
                else [
                    {
                        name: "measurement",
                        operation: "app.start",
                        startType: .sentryAppStartMeasurement.type,
                        prewarmed: .sentryAppStartMeasurement.isPreWarmed,
                        durationMs: .sentryAppStartMeasurement.durationMs
                    }
                ]
                end;
            def sentry_summary: measurement_summary + transaction_summaries + span_summaries;
            [
                .metadata.buildLabel,
                .metadata.sdkGeneration,
                .metadata.standaloneTracingEnabled,
                .activePrewarmDetected,
                (.early.debuggerAttached // false),
                (.derived.processToMainMs // ""),
                (.derived.processToDidFinishEndMs // ""),
                (.derived.processToFirstDisplayLinkMs // ""),
                (sentry_summary | @json),
                $file
            ] | @tsv
        ' "$report"
    done
}

simulate_prewarm() {
    require_device

    local process_file
    process_file="$(mktemp)"

    log_notice "Launching OS27-Prewarm suspended with ActivePrewarm=1"
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl device process launch \
        --device "$DEVICE" \
        --terminate-existing \
        --start-stopped \
        --environment-variables '{"ActivePrewarm":"1"}' \
        io.sentry.sample.iOS-Swift

    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl device info processes \
        --device "$DEVICE" \
        --json-output "$process_file" \
        --quiet

    local process_id
    process_id="$(jq -r '
        .result.runningProcesses[]
        | select(.executable | tostring | endswith("/OS27-Prewarm.app/OS27-Prewarm"))
        | .processIdentifier
    ' "$process_file" | tail -n 1)"
    rm -f "$process_file"

    if [[ -z "$process_id" || "$process_id" == "null" ]]; then
        log_error "Could not find the suspended OS27-Prewarm process"
        exit 1
    fi

    log_notice "Suspended process $process_id for $SUSPEND_SECONDS seconds"
    sleep "$SUSPEND_SECONDS"

    log_notice "Resuming simulated prewarm launch"
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl device process resume \
        --device "$DEVICE" \
        --pid "$process_id"

    log_notice "Waiting for the launch report"
    sleep 5
    collect_reports
}

collect_reports() {
    require_device
    local timestamp
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local destination="$OUTPUT/$timestamp"
    mkdir -p "$destination"

    log_notice "Collecting reports into $destination"
    DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" xcrun devicectl device copy from \
        --device "$DEVICE" \
        --domain-type appDataContainer \
        --domain-identifier io.sentry.sample.iOS-Swift \
        --source Documents/OS27Prewarm \
        --destination "$destination"

    INPUT="$destination"
    summarize_reports
}

case "$ACTION" in
    devices) list_devices ;;
    generate) generate_project ;;
    install) install_app ;;
    simulate-prewarm) simulate_prewarm ;;
    collect) collect_reports ;;
    summarize) summarize_reports ;;
    *)
        log_error "Unknown action: $ACTION"
        usage
        ;;
esac
