#!/bin/bash
set -eo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

# Prefer ScreenCaptureApprovals over manual TCC.db edits. Direct TCC.db writes
# break once TCC is entitlement-gated (macOS 27+).
begin_group "Screen capture approval"
log_info "Writing screen capture approval for /bin/bash"
defaults write ~/Library/Group\ Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist "/bin/bash" -date "3024-09-23 12:00:00 +0000"
end_group

log_info "CI permissions enabled successfully"
