#!/bin/bash
set -euo pipefail

# Temporary debugging helper for the visionOS 27 simulator backboardd crash loop on CI.
#
# backboardd aborts in AURemoteIO::Initialize ("RPC timeout") because a CoreAudio HAL call to the
# host never returns. This script boots the simulator with one mitigation applied, watches
# backboardd for a while, and collects host audio diagnostics.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

VARIANT="baseline"
OS_VERSION=""
DEVICE_NAME="Apple Vision Pro"
OBSERVE_SECONDS="420"
OUTPUT_DIR="visionos27-audio-debug"

usage() {
    log_info "Usage: $0"
    log_info "  -v, --variant <name>           Mitigation to apply (default: baseline). One of:"
    log_info "                                 baseline, headless, restart-coreaudiod-preboot,"
    log_info "                                 restart-coreaudiod-postboot, kickstart-watchdog, blackhole"
    log_info "  -o, --os-version <version>     visionOS simulator version, e.g. 27.2 (required)"
    log_info "  -d, --device <name>            Simulator device name (default: Apple Vision Pro)"
    log_info "  -s, --observe-seconds <n>      How long to watch backboardd after boot (default: 420)"
    log_info "  -u, --output-dir <path>        Directory for collected diagnostics (default: visionos27-audio-debug)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--variant) VARIANT="$2"; shift 2 ;;
        -o|--os-version) OS_VERSION="$2"; shift 2 ;;
        -d|--device) DEVICE_NAME="$2"; shift 2 ;;
        -s|--observe-seconds) OBSERVE_SECONDS="$2"; shift 2 ;;
        -u|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$OS_VERSION" ]; then
    log_error "Error: --os-version is required"
    usage
fi

case "$VARIANT" in
    baseline|headless|restart-coreaudiod-preboot|restart-coreaudiod-postboot|kickstart-watchdog|blackhole) ;;
    *)
        log_error "Unknown variant: $VARIANT"
        usage
        ;;
esac

mkdir -p "$OUTPUT_DIR"
REPORTS_DIR="$HOME/Library/Logs/DiagnosticReports"
MARKER="$OUTPUT_DIR/.start-marker"
WATCHDOG_PID=""

restart_coreaudiod() {
    log_info "Restarting host coreaudiod"
    log_info "coreaudiod before: $(pgrep -x coreaudiod | tr '\n' ' ')"
    if ! sudo -n launchctl kickstart -kp system/com.apple.audio.coreaudiod; then
        log_warning "launchctl kickstart failed, falling back to killall"
        sudo -n killall coreaudiod || log_warning "killall coreaudiod failed"
    fi
    sleep 5
    log_info "coreaudiod after: $(pgrep -x coreaudiod | tr '\n' ' ')"
}

install_blackhole() {
    log_info "Installing BlackHole virtual audio device"
    if ! NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask blackhole-2ch; then
        log_warning "Installing blackhole-2ch failed"
    fi
    if ! NONINTERACTIVE=1 HOMEBREW_NO_AUTO_UPDATE=1 brew install switchaudio-osx; then
        log_warning "Installing switchaudio-osx failed"
    fi
    restart_coreaudiod
    if command -v SwitchAudioSource > /dev/null; then
        SwitchAudioSource -a || true
        SwitchAudioSource -t output -s "BlackHole 2ch" || log_warning "Selecting BlackHole output failed"
        SwitchAudioSource -t input -s "BlackHole 2ch" || log_warning "Selecting BlackHole input failed"
        SwitchAudioSource -c -t output || true
        SwitchAudioSource -c -t input || true
    fi
}

log_host_audio_state() {
    local label="$1"
    begin_group "Host audio state ($label)"
    sw_vers || true
    if sudo -n true 2> /dev/null; then
        log_info "Passwordless sudo: yes"
    else
        log_info "Passwordless sudo: no"
    fi
    csrutil status || true
    system_profiler SPAudioDataType || true
    pgrep -fl -i "coreaudiod|audiomxd|SimAudio|SimulatorAudio|tccd|UserNotificationCenter" || true
    end_group
}

new_backboardd_reports() {
    find "$REPORTS_DIR" -name 'backboardd*.ips' -newer "$MARKER" 2> /dev/null | sort
}

backboardd_status() {
    local count pid etime
    count=$(new_backboardd_reports | wc -l | tr -d ' ')
    pid=$(pgrep -x backboardd | head -n1 || true)
    if [ -n "$pid" ]; then
        etime=$(ps -o etime= -p "$pid" | tr -d ' ' || true)
        log_info "backboardd crash reports so far: $count; running pid $pid for $etime"
    else
        log_info "backboardd crash reports so far: $count; not running"
    fi
}

collect_hang_samples() {
    local label="$1"
    local pid
    begin_group "Hang samples ($label)"
    pid=$(pgrep -x backboardd | head -n1 || true)
    if [ -n "$pid" ]; then
        sample "$pid" 3 -file "$OUTPUT_DIR/backboardd-$label.sample.txt" > /dev/null 2>&1 || log_warning "Sampling backboardd failed"
    else
        log_info "backboardd not running, skipping sample"
    fi
    sudo -n sample coreaudiod 3 -file "$OUTPUT_DIR/coreaudiod-$label.sample.txt" > /dev/null 2>&1 || log_warning "Sampling coreaudiod failed"
    screencapture -x "$OUTPUT_DIR/screen-$label.png" || log_warning "Screenshot failed"
    if [ -f "$OUTPUT_DIR/backboardd-$label.sample.txt" ]; then
        log_info "backboardd frames mentioning audio:"
        grep -E "HALC_|AURemoteIO|AQMEIO|_ReportRPCTimeout|PHASE" "$OUTPUT_DIR/backboardd-$label.sample.txt" | head -n 30 || true
    fi
    if [ -f "$OUTPUT_DIR/coreaudiod-$label.sample.txt" ]; then
        log_info "coreaudiod call graph (first 120 lines):"
        sed -n '/Call graph:/,/Total number in stack/p' "$OUTPUT_DIR/coreaudiod-$label.sample.txt" | head -n 120 || true
    fi
    end_group
}

run_kickstart_watchdog() {
    local udid="$1"
    while true; do
        if ! pgrep -x backboardd > /dev/null; then
            if xcrun simctl spawn "$udid" launchctl kickstart system/com.apple.backboardd >> "$OUTPUT_DIR/watchdog.log" 2>&1; then
                echo "$(date -u +%H:%M:%S) kickstart ok" >> "$OUTPUT_DIR/watchdog.log"
            else
                echo "$(date -u +%H:%M:%S) kickstart failed" >> "$OUTPUT_DIR/watchdog.log"
            fi
        fi
        sleep 2
    done
}

cleanup() {
    if [ -n "$WATCHDOG_PID" ]; then
        kill "$WATCHDOG_PID" 2> /dev/null || true
    fi
}
trap cleanup EXIT

log_info "Variant: $VARIANT, visionOS $OS_VERSION, device: $DEVICE_NAME, observing ${OBSERVE_SECONDS}s"
log_host_audio_state "initial"

# === Pre-boot mitigation ===
case "$VARIANT" in
    restart-coreaudiod-preboot)
        begin_group "Mitigation: restart coreaudiod before boot"
        restart_coreaudiod
        end_group
        ;;
    blackhole)
        begin_group "Mitigation: BlackHole virtual audio device"
        install_blackhole
        end_group
        log_host_audio_state "after BlackHole"
        ;;
    *) ;;
esac

# === Boot ===
begin_group "Boot simulator"
RUNTIME_KEY="com.apple.CoreSimulator.SimRuntime.xrOS-${OS_VERSION//./-}"
UDID=$(xcrun simctl list devices available -j | jq -r --arg runtime "$RUNTIME_KEY" --arg name "$DEVICE_NAME" \
    '.devices[$runtime] // [] | map(select(.name == $name)) | first | .udid // empty')
if [ -z "$UDID" ]; then
    xcrun simctl list devices available
    log_error "No '$DEVICE_NAME' simulator found for $RUNTIME_KEY"
    exit 1
fi
log_info "Using simulator $UDID"

touch "$MARKER"
BOOT_STARTED=$(date -u +%H:%M:%S)
xcrun simctl boot "$UDID"

if [ "$VARIANT" != "headless" ]; then
    DEVELOPER_DIR_PATH="$(xcode-select -p)"
    SIMULATOR_APP_PATH="$DEVELOPER_DIR_PATH/Applications/Simulator.app"
    DEVICE_HUB_APP_PATH="$(dirname "$DEVELOPER_DIR_PATH")/Applications/DeviceHub.app"
    if [ -d "$SIMULATOR_APP_PATH" ]; then
        log_info "Opening Simulator app"
        open "$SIMULATOR_APP_PATH" || log_warning "Opening Simulator app failed"
    elif [ -d "$DEVICE_HUB_APP_PATH" ]; then
        log_info "Opening Device Hub"
        open "$DEVICE_HUB_APP_PATH" || log_warning "Opening Device Hub failed"
        open "devices://device/open?id=$UDID" || log_warning "Focusing simulator in Device Hub failed"
    else
        log_info "No simulator UI app found"
    fi
fi

xcrun simctl bootstatus "$UDID" || log_warning "bootstatus failed"
log_info "Boot started at $BOOT_STARTED, finished at $(date -u +%H:%M:%S)"
end_group

# === Post-boot mitigation ===
case "$VARIANT" in
    restart-coreaudiod-postboot)
        collect_hang_samples "before-restart"
        begin_group "Mitigation: restart coreaudiod after boot"
        restart_coreaudiod
        end_group
        ;;
    kickstart-watchdog)
        log_info "Starting backboardd kickstart watchdog"
        xcrun simctl spawn "$UDID" launchctl print system/com.apple.backboardd > "$OUTPUT_DIR/launchctl-print-backboardd.txt" 2>&1 || log_warning "launchctl print failed"
        run_kickstart_watchdog "$UDID" &
        WATCHDOG_PID=$!
        ;;
    *) ;;
esac

# === Observe ===
begin_group "Observe backboardd"
ELAPSED=0
SAMPLED="false"
while [ "$ELAPSED" -lt "$OBSERVE_SECONDS" ]; do
    backboardd_status
    if [ "$SAMPLED" = "false" ] && [ "$ELAPSED" -ge 30 ]; then
        end_group
        collect_hang_samples "observe"
        begin_group "Observe backboardd (continued)"
        SAMPLED="true"
    fi
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done
sleep 10
backboardd_status
end_group

# === Results ===
begin_group "backboardd crash reports"
CRASH_COUNT=0
while IFS= read -r report; do
    [ -z "$report" ] && continue
    CRASH_COUNT=$((CRASH_COUNT + 1))
    tail -n +2 "$report" | jq -r '[.procLaunch, .captureTime, (.pid | tostring)] | @tsv' || log_warning "Could not parse $report"
    cp "$report" "$OUTPUT_DIR/" || true
done < <(new_backboardd_reports)
log_info "Total backboardd crash reports: $CRASH_COUNT"
end_group

begin_group "Collect logs"
log show --last 12m --style compact --predicate 'process == "coreaudiod"' > "$OUTPUT_DIR/host-coreaudiod.log" 2>&1 || log_warning "log show coreaudiod failed"
log show --last 12m --style compact --info --predicate 'subsystem == "com.apple.TCC" OR process == "tccd"' > "$OUTPUT_DIR/host-tcc.log" 2>&1 || log_warning "log show TCC failed"
xcrun simctl spawn "$UDID" log show --last 12m --style compact --predicate 'process == "backboardd"' > "$OUTPUT_DIR/sim-backboardd.log" 2>&1 || log_warning "sim log show failed"
log_info "Microphone/audio TCC lines:"
grep -i -E "microphone|kTCCServiceMicrophone|kTCCServiceAudioCapture" "$OUTPUT_DIR/host-tcc.log" | tail -n 40 || true
log_info "coreaudiod log tail:"
tail -n 60 "$OUTPUT_DIR/host-coreaudiod.log" || true
log_info "backboardd audio log lines:"
grep -i -E "audio|RPC timeout|deadlock" "$OUTPUT_DIR/sim-backboardd.log" | tail -n 60 || true
for db in "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "/Library/Application Support/com.apple.TCC/TCC.db"; do
    log_info "TCC microphone entries in $db:"
    sudo -n sqlite3 "$db" "select service, client, client_type, auth_value, auth_reason from access where service in ('kTCCServiceMicrophone', 'kTCCServiceAudioCapture');" || log_warning "Reading $db failed"
done
if [ -f "$OUTPUT_DIR/watchdog.log" ]; then
    log_info "Watchdog log:"
    cat "$OUTPUT_DIR/watchdog.log"
fi
end_group

log_host_audio_state "final"

append_summary "### visionOS 27 audio debug: \`$VARIANT\`"
append_summary "backboardd crash reports in ${OBSERVE_SECONDS}s: **$CRASH_COUNT**"
log_notice "Variant $VARIANT: $CRASH_COUNT backboardd crash reports in ${OBSERVE_SECONDS}s"
