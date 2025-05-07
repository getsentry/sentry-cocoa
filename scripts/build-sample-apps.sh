#!/usr/bin/env bash

# Function to build a sample app
build_app() {
  local xcodeproj=$1
  local scheme=$2
  local destination=$3
  local log_file="/tmp/${scheme}.log"

  cmd="xcodebuild build -project \"${xcodeproj}\" -scheme \"${scheme}\" -destination \"${destination}\" > \"${log_file}\" 2>&1"
  echo "Executing: $cmd"
  if eval "${cmd}"; then
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
  ["iOS15-SwiftUI"]="./Samples/iOS15-SwiftUI/iOS15-SwiftUI.xcodeproj"
  ["iOS-ObjectiveC"]="./Samples/iOS-ObjectiveC/iOS-ObjectiveC.xcodeproj"
)

declare -A projects_and_destinations=(
  ["iOS13-Swift"]="generic/platform=iOS"
  ["iOS-SwiftUI"]="generic/platform=iOS"
  ["iOS-Swift6"]="generic/platform=iOS"
  ["iOS-Swift"]="generic/platform=iOS"
  ["watchOS-Swift WatchKit App"]="generic/platform=watchOS"
  ["visionOS-Swift"]="generic/platform=visionOS"
  ["tvOS-Swift"]="generic/platform=tvOS"
  ["macOS-SwiftUI"]="generic/platform=macOS"
  ["macOS-Swift"]="generic/platform=macOS"
  ["iOS15-SwiftUI"]="generic/platform=iOS"
  ["iOS-ObjectiveC"]="generic/platform=iOS"
)

# Iterate over the associative array and build each project with its scheme
for xcodeproj in "${!projects_and_schemes[@]}"; do
  scheme="${projects_and_schemes[$xcodeproj]}"
  destination="${projects_and_destinations[$xcodeproj]}"
  build_app "$xcodeproj" "$scheme" "$destination" &
done

# Wait for all background jobs to finish
wait
