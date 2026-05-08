#!/bin/bash

set -euo pipefail

# Disable SC1091 because it won't work with pre-commit
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Start the test server (./test-server-exec) in the background and wait
up to 20 seconds for it to respond on http://localhost:8080.

EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

is_server_running() {
    curl -s http://localhost:8080/echo-baggage-header > /dev/null 2>&1
}

begin_group "Starting test server"

log_info "Making test server executable"
chmod +x ./test-server-exec

log_info "Start the test server in the background"
./test-server-exec &

log_info "Waiting up to 20 seconds for the test server to respond"

start_time=$(date +%s)
server_started=false

while true; do
    if is_server_running; then
        log_info "Test server is running and responding."
        server_started=true
        break
    else
        log_info "Test server is not yet responding, waiting..."
    fi

    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -ge 20 ]; then
        break
    fi

    sleep 0.1
done

end_group

if [ "$server_started" = true ]; then
    log_info "Test server successfully started and is responding at http://localhost:8080"
else
    log_error "Test server failed to start or is not responding after 20 seconds"
    exit 1
fi
