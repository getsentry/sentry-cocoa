#!/bin/bash

# Read the line containing the version from the file
version_line=$(grep 's.version' Sentry.podspec)

# Extract the version using awk
version=$(echo "$version_line" | awk -F'"' '{print $2}')

# Print the version
echo "$version"
