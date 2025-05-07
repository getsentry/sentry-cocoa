#!/usr/bin/env bash

# Function to build a sample app
build_app() {
  local xcodeproj=$1
  local scheme=$2
  local destination=$3
  local log_file="/tmp/${scheme}.log"
  local derived_data_path="/tmp/${scheme}"
  cmd="xcodebuild build -project \"${xcodeproj}\" -scheme \"${scheme}\" -destination \"${destination}\" -configuration Debug -derivedDataPath \"${derived_data_path}\""
  echo "$cmd"
  if eval "${cmd}" > "${log_file}" 2>&1; then
    echo "${xcodeproj}::${scheme}: success"
  else
    echo "${xcodeproj}::${scheme}: failed (see ${log_file})"
  fi
}

# Define an associative array with xcodeproj paths as keys and schemes as values
declare -A projects_and_schemes=(
  ["iOS13-Swift"]="./Samples/iOS13-Swift/iOS13-Swift.xcodeproj"
  ["iOS-SwiftUI"]="./Samples/iOS-SwiftUI/iOS-SwiftUI.xcodeproj"
  ["iOS-Swift6"]="./Samples/iOS-Swift6/iOS-Swift6.xcodeproj"
  ["iOS-Swift"]="./Samples/iOS-Swift/iOS-Swift.xcodeproj"
  ["watchOS-Swift WatchKit App"]="./Samples/watchOS-Swift/watchOS-Swift.xcodeproj"
  ["visionOS-Swift"]="./Samples/visionOS-Swift/visionOS-Swift.xcodeproj"
  ["tvOS-Swift"]="./Samples/tvOS-Swift/tvOS-Swift.xcodeproj"
  ["macOS-SwiftUI"]="./Samples/macOS-SwiftUI/macOS-SwiftUI.xcodeproj"
  ["macOS-Swift"]="./Samples/macOS-Swift/macOS-Swift.xcodeproj"
  ["macOS-Swift-Other"]="./Samples/macOS-Swift/macOS-Swift.xcodeproj"
  ["macOS-Swift-Sandboxed"]="./Samples/macOS-Swift/macOS-Swift.xcodeproj"
  ["macOS-Swift-Sandboxed-Other"]="./Samples/macOS-Swift/macOS-Swift.xcodeproj"
  ["iOS15-SwiftUI"]="./Samples/iOS15-SwiftUI/iOS15-SwiftUI.xcodeproj"
  ["iOS-ObjectiveC"]="./Samples/iOS-ObjectiveC/iOS-ObjectiveC.xcodeproj"
)

resolve_destination_for_watch_pair() {
  local sim_data
  sim_data=$(xcrun simctl list -j)

  # Use jq to extract the latest available device pair
  local pair_info
  pair_info=$(echo "$sim_data" | jq -r '
    .pairs | to_entries[0].value | "\(.watch.udid) \(.phone.udid)"' | head -n1)

  local watch_udid
  local phone_udid
  read -r watch_udid phone_udid <<< "$pair_info"

  if [[ -z "$watch_udid" || -z "$phone_udid" ]]; then
    echo "❌ Could not find matching simulators for a watch and phone pair."
    return 1
  fi

  echo "platform=watchOS Simulator,id=$watch_udid,pairedWith=$phone_udid"
}

watch_destination=$(resolve_destination_for_watch_pair)

declare -A projects_and_destinations=(
  ["iOS13-Swift"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
  ["iOS-SwiftUI"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
  ["iOS-Swift6"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
  ["iOS-Swift"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
  ["watchOS-Swift WatchKit App"]="$watch_destination"
  ["visionOS-Swift"]="platform=visionOS Simulator,OS=latest,name=Apple Vision Pro"
  ["tvOS-Swift"]="platform=tvOS Simulator,OS=latest,name=Apple TV"
  ["macOS-SwiftUI"]="platform=macOS"
  ["macOS-Swift"]="platform=macOS"
  ["macOS-Swift-Other"]="platform=macOS"
  ["macOS-Swift-Sandboxed"]="platform=macOS"
  ["macOS-Swift-Sandboxed-Other"]="platform=macOS"
  ["iOS15-SwiftUI"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
  ["iOS-ObjectiveC"]="platform=iOS Simulator,OS=latest,name=iPhone 16"
)

# Iterate over the associative array and build each project with its scheme
for scheme in "${!projects_and_schemes[@]}"; do
  xcodeproj="${projects_and_schemes[$scheme]}"
  destination="${projects_and_destinations[$scheme]}"
  build_app "$xcodeproj" "$scheme" "$destination" &
done

# Wait for all background jobs to finish
wait
