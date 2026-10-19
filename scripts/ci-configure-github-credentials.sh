#!/bin/bash

# Configures a global git credential helper for https://github.com that
# answers with the workflow's GITHUB_TOKEN.
#
# SwiftPM clones package dependencies (e.g. getsentry/KSCrash) with the git
# CLI and no credentials. GitHub intermittently rejects anonymous HTTPS
# fetches of public repositories with a 401, which makes git try to prompt for
# a username and fail with "terminal prompts disabled". With this helper, git
# retries the rejected request authenticated instead of failing.
#
# The helper is only consulted after GitHub asks for credentials, so requests
# that already authenticate (e.g. the actions/checkout extraheader) or succeed
# anonymously are unchanged. The token is stored in a file under RUNNER_TEMP,
# which the runner deletes when the job finishes; if the file is gone, the
# helper returns nothing and git falls back to its default behavior.
#
# Reads the token from the GITHUB_TOKEN environment variable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

TOKEN_FILE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/github-git-credentials-token"

usage() {
    log_info "Usage: $0 [options]"
    log_info "  -f, --token-file <path>    File that stores the token (default: \$RUNNER_TEMP/github-git-credentials-token)"
    log_info "  -h, --help                 Show this help"
    log_info ""
    log_info "Environment:"
    log_info "  GITHUB_TOKEN               Token used to authenticate github.com fetches (required)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--token-file) TOKEN_FILE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done

if [ -z "${GITHUB_TOKEN:-}" ]; then
    log_warning "GITHUB_TOKEN is not set; skipping git credential helper setup."
    exit 0
fi

umask 077
mkdir -p "$(dirname "$TOKEN_FILE")"
printf '%s' "$GITHUB_TOKEN" > "$TOKEN_FILE"

CREDENTIAL_KEY="credential.https://github.com.helper"
# shellcheck disable=SC2016 # Expanded by git when the helper runs.
HELPER='!f() { test "$1" = get && test -r "'"$TOKEN_FILE"'" || return 0; printf "username=x-access-token\npassword=%s\n" "$(cat "'"$TOKEN_FILE"'")"; }; f'

# An empty helper resets helpers from the system config (e.g. osxkeychain), so
# the short-lived token is neither read from nor stored in the keychain.
git config --global --unset-all "$CREDENTIAL_KEY" || true
git config --global --add "$CREDENTIAL_KEY" ""
git config --global --add "$CREDENTIAL_KEY" "$HELPER"

log_info "Configured git credential helper for https://github.com"
