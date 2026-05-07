#!/bin/bash
set -eo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

if csrutil status | grep -q 'disabled'; then
    begin_group "Update TCC database"
    epochdate=$(($(date +'%s * 1000 + %-N / 1000000')))
    macos_major_version=$(sw_vers -productVersion | awk -F. '{ print $1 }')
    if [[ $macos_major_version -le 10 ]]; then
        tcc_update="replace into access (service,client,client_type,allowed,prompt_count,indirect_object_identifier,flags,last_modified) values (\"kTCCServiceScreenCapture\",\"/bin/bash\",0,1,1,\"UNUSED\",0,$epochdate);"
    else
        tcc_update="replace into access (service,client,client_type,auth_value,auth_reason,auth_version,indirect_object_identifier,flags,last_modified) values (\"kTCCServiceScreenCapture\",\"/bin/bash\",0,2,1,1,\"UNUSED\",0,$epochdate);"
    fi
    echo "Updating system TCC database"
    sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$tcc_update"
    echo "Updating user TCC database"
    sudo sqlite3 "/Users/$USER/Library/Application Support/com.apple.TCC/TCC.db" "$tcc_update"
    end_group
else
    log_error "Unable to add permissions! System Integrity Protection is enabled on this image"
    exit 1
fi

begin_group "Screen capture approval"
echo "Writing screen capture approval for /bin/bash"
defaults write ~/Library/Group\ Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist "/bin/bash" -date "3024-09-23 12:00:00 +0000"
end_group

echo "CI permissions enabled successfully"
