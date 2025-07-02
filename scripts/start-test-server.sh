#!/bin/bash

set -euo pipefail

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

is_server_running() {
    curl -s http://localhost:8080/echo-baggage-header > /dev/null 2>&1
}

log "🚀 Starting test server..."

log "Make the test server executable"
chmod +x ./test-server-exec

log "Start the test server in the background"
./test-server-exec &

log "⏳ Waiting for 5 seconds that the test server to responds"

start_time=$(date +%s)
server_started=false

while true; do
    if is_server_running; then
        log "✅ Test server is running and responding."
        server_started=true
        break
    else
        log "⏳ Test server is not yet responding, waiting..."
    fi

    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -ge 5 ]; then
        break
    fi
    
    sleep 0.1
done

if [ "$server_started" = true ]; then
    log "✅ Test server successfully started and is responding at http://localhost:8080"
else
    log "❌ Test server failed to start or is not responding after 5 seconds"
    exit 1
fi 
