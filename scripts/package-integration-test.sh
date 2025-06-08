#!/bin/bash

set -eou pipefail

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

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <platform> <packageType>"
    echo "platform: ios, tvos, watchos, macos, visionos"
    echo "packageType: carthage, cocoapods, spm, xcframework-static, xcframework-dynamic"
    exit 1
fi

PLATFORM=$1
PROPER_CASE_PLATFORM=$(get_proper_case_platform "$PLATFORM")
PACKAGE_TYPE=$2

echo "--------------------------------"
echo "Testing integration on $PROPER_CASE_PLATFORM via $PACKAGE_TYPE"
echo "--------------------------------"

DEPLOYMENT_TARGET=$(get_deployment_target "$PLATFORM")

if [[ -z "$DEPLOYMENT_TARGET" ]]; then
    echo "Invalid platform: $PLATFORM"
    exit 1
fi

PROJECT_NAME="project-$PLATFORM-$PACKAGE_TYPE"
PROJECT_DIR="Integration/$PROJECT_NAME"
SPEC_FILENAME="$PROJECT_NAME.yml"
SPEC_PATH="$PROJECT_DIR/$SPEC_FILENAME"

mkdir -p "$PROJECT_DIR"

# Create the XcodeGen spec
cat > "$SPEC_PATH" <<EOL
name: $PROJECT_NAME
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    $PLATFORM: '$DEPLOYMENT_TARGET'
fileGroups: 
  - ./$SPEC_FILENAME
EOL

if [ "$PACKAGE_TYPE" = "carthage" ]; then
cat >> "$SPEC_PATH" <<EOL
  - ./Cartfile
  - ./Sentry.Carthage.json
  - ./SentrySwiftUI.Carthage.json
EOL
fi

cat >> "$SPEC_PATH" <<EOL
targets:
  ${PROPER_CASE_PLATFORM}App:
    type: application
    platform: $PROPER_CASE_PLATFORM
    sources: [../Sources]
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

# Add dependencies based on the package type
case $PACKAGE_TYPE in
    spm)
        cat >> "$SPEC_PATH" <<EOL
    dependencies:
      - package: Sentry
packages:
  Sentry:
    path: ../..
EOL

        PACKAGE_FILE_PATH="$PROJECT_DIR/Package.swift"
        cp Package.swift "$PACKAGE_FILE_PATH"

        # Modify Package.swift for SPM
        sed -i '' 's/url.*//g' "$PACKAGE_FILE_PATH"
        sed -i '' 's/checksum: ".*" \/\/Sentry-Static/path: ".\/Integration\/Frameworks\/Sentry.xcframework.zip"/g' "$PACKAGE_FILE_PATH"
        sed -i '' 's/checksum: ".*" \/\/Sentry-Dynamic/path: ".\/Integration\/Frameworks\/Sentry-Dynamic.xcframework.zip"/g' "$PACKAGE_FILE_PATH"
        ;;

    carthage)
        ./scripts/create-carthage-json.sh "$PROJECT_DIR" "$(pwd)/Integration/Frameworks"

        cat > "$PROJECT_DIR/Cartfile" <<EOL
binary "./Sentry.Carthage.json" ~> 1.0
binary "./SentrySwiftUI.Carthage.json" ~> 1.0
EOL

        pushd "$PROJECT_DIR"
        carthage update --use-xcframeworks
        popd

        cat >> "$SPEC_PATH" <<EOL
    dependencies:
        - framework: ./Carthage/Build/Sentry.xcframework
        - framework: ./Carthage/Build/SentrySwiftUI.xcframework
EOL
        ;;

    xcframework-static)
        cat >> "$SPEC_PATH" <<EOL
    dependencies:
        - framework: ../Frameworks/Sentry.xcframework
EOL
        ;;

    xcframework-dynamic)
        cat >> "$SPEC_PATH" <<EOL
    dependencies:
        - framework: ../Frameworks/Sentry-Dynamic.xcframework
        - framework: ../Frameworks/SentrySwiftUI.xcframework
EOL
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
    cat > "$PROJECT_DIR/Podfile" <<EOL
platform :$PLATFORM, '$DEPLOYMENT_TARGET'
project '$PROJECT_NAME.xcodeproj'
target '${PROPER_CASE_PLATFORM}App' do
  pod 'Sentry', :path => '../..'
end
EOL
    pushd "$PROJECT_DIR"
    if command -v rbenv >/dev/null; then
        if ! rbenv version | grep -q "$(cat ../../.ruby-version)"; then
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
    container="-workspace $PROJECT_DIR/$PROJECT_NAME.xcworkspace"
else
    container="-project $PROJECT_DIR/$PROJECT_NAME.xcodeproj"
fi

# Function to get a valid destination specifier for each platform
get_destination_specifier() {
  case $1 in
    ios) echo "platform=iOS Simulator,name=iPhone 16,OS=18.4" ;;
    tvos) echo "platform=tvOS Simulator,name=Apple TV,OS=18.4" ;;
    watchos) echo "platform=watchOS Simulator,name=Apple Watch Series 10 (42mm),OS=11.4" ;;
    macos) echo "platform=macOS,arch=arm64" ;;
    visionos) echo "platform=visionOS Simulator,name=Apple Vision Pro,OS=2.4" ;;
    *) echo "Invalid platform: $1"; exit 1 ;;
  esac
}

# Get the destination specifier for the specified platform
destination=$(get_destination_specifier "$PLATFORM")

# Update the xcodebuild command with the new destination
xcodebuild_cmd="xcodebuild $container -scheme ${PROPER_CASE_PLATFORM}App -configuration Debug -destination \"$destination\" -quiet build | tee $PROJECT_DIR/$PROJECT_NAME.build.log"

# Print and execute the xcodebuild command
echo "Running: $xcodebuild_cmd"
eval "$xcodebuild_cmd"
