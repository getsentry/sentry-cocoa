#!/bin/bash

# Delete all watchOS and visionOS simulators

echo "Fetching list of all simulators..."
simctl_list=$(xcrun simctl list -j devices)

# Extract simulator UDIDs for watchOS and visionOS
watchos_udids=$(echo "$simctl_list" | jq -r '.devices | to_entries[] | select(.key | test("watchOS")) | .value[] | .udid')
visionos_udids=$(echo "$simctl_list" | jq -r '.devices | to_entries[] | select(.key | test("visionOS")) | .value[] | .udid')

# Combine both lists
udids=$(echo -e "$watchos_udids\n$visionos_udids")

if [[ -z "$udids" ]]; then
  echo "No watchOS or visionOS simulators found."
  exit 0
fi

# Delete each simulator by UDID
echo "Deleting the following simulators:"
echo "$udids"

for udid in $udids; do
  echo "Deleting simulator: $udid"
  xcrun simctl delete "$udid"
done

echo "✅ All watchOS and visionOS simulators deleted."
