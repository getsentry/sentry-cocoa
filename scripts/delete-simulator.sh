#!/bin/bash

set -euo pipefail

# SENTRY_SIMULATOR_UUID is set by create-simulator.sh
if [ -z "${SENTRY_SIMULATOR_UUID}" ]; then
  echo "No simulator UUID provided"
  exit 0
fi

uuid="${SENTRY_SIMULATOR_UUID}"

xcrun simctl shutdown "${uuid}"
echo "Shutdown simulator with UUID ${uuid}"

xcrun simctl delete "${uuid}"
echo "Deleted simulator with UUID ${uuid}"
