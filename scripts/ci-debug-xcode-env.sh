#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=./ci-utils.sh
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

log_notice "Starting Xcode/macOS environment diagnostics"

begin_group "System information"
echo "Date (UTC): $(date -u)"
echo "uname: $(uname -a)"
if command -v sw_vers >/dev/null 2>&1; then
  sw_vers
fi
end_group

begin_group "Developer directory"
echo "DEVELOPER_DIR=${DEVELOPER_DIR:-<not set>}"
if command -v xcode-select >/dev/null 2>&1; then
  xcode-select -p
fi
end_group

begin_group "Installed Xcode applications"
if compgen -G "/Applications/Xcode*" > /dev/null; then
  for app in /Applications/Xcode*; do
    basename "$app"
  done
else
  log_warning "No Xcode apps found in /Applications"
fi
end_group

begin_group "Active Xcode"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version || true
else
  log_warning "xcodebuild not found in PATH"
fi
end_group

begin_group "Installed SDKs (xcodebuild -showsdks)"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -showsdks || true
fi
end_group

begin_group "SDK details (xcodebuild -version -sdk)"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version -sdk || true
fi
end_group

begin_group "Available simulator runtimes"
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl list runtimes || true
fi
end_group

begin_group "Available simulator device types"
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl list devicetypes || true
fi
end_group

begin_group "Available simulator devices"
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl list devices available || true
fi
end_group

begin_group "Available destinations (best effort)"
if [ -d "Sentry.xcworkspace" ] && command -v xcodebuild >/dev/null 2>&1; then
  # Do not fail if scheme isn't configured; this is best-effort
  xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -showdestinations 2>/dev/null || true
else
  log_warning "Skipping: workspace or xcodebuild not available"
fi
end_group

begin_group "Hardware summary"
if command -v system_profiler >/dev/null 2>&1; then
  system_profiler SPHardwareDataType | sed -e 's/^[[:space:]]*//' || true
fi
end_group

begin_group "Disk space"
df -h || true
end_group

log_notice "Completed Xcode/macOS environment diagnostics"
