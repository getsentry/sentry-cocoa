#!/bin/bash

set -eoux pipefail

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <platform> <packageType>"
    echo "platform: ios, tvos, watchos, macos, visionos"
    echo "packageType: carthage, cocoapods, spm, xcframework-static, xcframework-dynamic"
    exit 1
fi

PLATFORM=$1
PACKAGE_TYPE=$2

echo "Platform: $PLATFORM"

# Function to get deployment target for a platform
get_deployment_target() {
  case $1 in
    ios) echo "13.0" ;;
    tvos) echo "13.0" ;;
    watchos) echo "6.0" ;;
    macos) echo "10.15" ;;
    visionos) echo "1.0" ;;
    *) echo "Invalid platform: $1"; exit 1 ;;
  esac
}

# Get the deployment target for the specified platform
DEPLOYMENT_TARGET=$(get_deployment_target "$PLATFORM")

# Debug statement to print the deployment target for the platform
echo "Deployment target for $PLATFORM: $DEPLOYMENT_TARGET"

# Check if the platform is valid
if [[ -z "$DEPLOYMENT_TARGET" ]]; then
    echo "Invalid platform: $PLATFORM"
    exit 1
fi

# Define the XcodeGen spec file path
PROJECT_NAME="project-$PLATFORM-$PACKAGE_TYPE"
SPEC_PATH="Integration/$PROJECT_NAME.yml"

# Function to map platform names to their proper case
get_proper_case_platform() {
  case $1 in
    ios) echo "iOS" ;;
    tvos) echo "tvOS" ;;
    watchos) echo "watchOS" ;;
    macos) echo "macOS" ;;
    visionos) echo "visionOS" ;;
    *) echo "Invalid platform: $1"; exit 1 ;;
  esac
}

# Get the proper case platform name
PROPER_CASE_PLATFORM=$(get_proper_case_platform "$PLATFORM")

# Create the XcodeGen spec
cat > "$SPEC_PATH" <<EOL
name: $PROJECT_NAME
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    $PLATFORM: '$DEPLOYMENT_TARGET'
targets:
  ${PROPER_CASE_PLATFORM}App:
    type: application
    platform: $PROPER_CASE_PLATFORM
    sources: [Sources]
    info:
      path: Info.plist
      properties:
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        UIRequiredDeviceCapabilities: ["armv7"]
EOL

if [ "$PLATFORM" == "ios" ]; then
    cat >> "$SPEC_PATH" <<EOL
        UISupportedInterfaceOrientations:
          - "UIInterfaceOrientationPortrait"
          - "UIInterfaceOrientationLandscapeLeft"
          - "UIInterfaceOrientationLandscapeRight"
EOL
fi

cat >> "$SPEC_PATH" <<EOL
    dependencies:
EOL

# Add dependencies based on the package type
case $PACKAGE_TYPE in
    spm)
        cat >> "$SPEC_PATH" <<EOL
      - package: Sentry
packages:
  Sentry:
    path: .
EOL
        # Modify Package.swift for SPM
        sed -i '' 's/url.*//g' Package.swift
        sed -i '' 's/checksum: ".*" \/\/Sentry-Static/path: "Frameworks/Sentry.xcframework.zip"/g' Package.swift
        sed -i '' 's/checksum: ".*" \/\/Sentry-Dynamic/path: "Frameworks/Sentry-Dynamic.xcframework.zip"/g' Package.swift
        ;;
    carthage)
        echo "      - carthage: Sentry" >> "$SPEC_PATH"
        ;;
    xcframework-static)
        echo "      - framework: Frameworks/Sentry.xcframework" >> "$SPEC_PATH"
        ;;
    xcframework-dynamic)
        echo "      - framework: Frameworks/Sentry-Dynamic.xcframework" >> "$SPEC_PATH"
        echo "      - framework: Frameworks/SentrySwiftUI.xcframework" >> "$SPEC_PATH"
        ;;
    cocoapods)
        # we'll handle this case after generating the xcode project
        ;;
    *)
        echo "Invalid package type: $PACKAGE_TYPE"
        exit 1
        ;;
esac

echo "XcodeGen spec generated at $SPEC_PATH"

xcodegen generate --spec "$SPEC_PATH"

if [ "$PACKAGE_TYPE" == "cocoapods" ]; then
    # Write a Podfile
    cat > Integration/Podfile <<EOL
platform :$PLATFORM, '$DEPLOYMENT_TARGET'
target '${PROPER_CASE_PLATFORM}App' do
  pod 'Sentry', :path => '.'
end
EOL
    pushd Integration
    if command -v rbenv >/dev/null; then
        if ! rbenv version | grep -q "$(cat .ruby-version)"; then
            echo "Ruby version $(cat .ruby-version) is not installed. Run make init to install it and try again."
            exit 1
        fi
        rbenv exec bundle exec pod install
    else
        bundle exec pod install
    fi
    popd
fi

# build the app in the project to validate compilation and linking of the SDK
if [ "$PACKAGE_TYPE" == "cocoapods" ]; then
    container="-workspace Integration/$PROJECT_NAME.xcworkspace"
else
    container="-project Integration/$PROJECT_NAME.xcodeproj"
fi

# Function to get a valid destination specifier for each platform
get_destination_specifier() {
  case $1 in
    ios) echo "platform=iOS Simulator,name=iPhone 16,OS=18.4" ;;
    tvos) echo "platform=tvOS Simulator,name=Apple TV,OS=16.0" ;;
    watchos) echo "platform=watchOS Simulator,name=Apple Watch Series 8 - 45mm,OS=9.0" ;;
    macos) echo "platform=macOS,arch=arm64" ;;
    visionos) echo "platform=visionOS Simulator,name=Apple Vision Pro,OS=2.3" ;;
    *) echo "Invalid platform: $1"; exit 1 ;;
  esac
}

# Get the destination specifier for the specified platform
destination=$(get_destination_specifier "$PLATFORM")

# Update the xcodebuild command with the new destination
xcodebuild_cmd="xcodebuild $container -scheme ${PROPER_CASE_PLATFORM}App -configuration Debug -destination \"$destination\" build"

# Print and execute the xcodebuild command
echo "Running: $xcodebuild_cmd"
eval "$xcodebuild_cmd"
