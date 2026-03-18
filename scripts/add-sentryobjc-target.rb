#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds SentryObjC framework target to Sentry.xcodeproj
# Usage: bundle exec ruby scripts/add-sentryobjc-target.rb

require 'xcodeproj'

PROJECT_PATH = 'Sentry.xcodeproj'
TARGET_NAME = 'SentryObjC'

# Source files for SentryObjC target (pure ObjC, no Swift bridge)
OBJC_SOURCES = Dir.glob('Sources/SentryObjC/**/*.m')
OBJC_HEADERS = Dir.glob('Sources/SentryObjC/**/*.h')

# Swift bridge files
SWIFT_SOURCES = Dir.glob('Sources/SentryObjCBridge/**/*.swift')

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Check if target already exists
if project.targets.find { |t| t.name == TARGET_NAME }
  puts "Target '#{TARGET_NAME}' already exists. Removing and recreating..."
  target = project.targets.find { |t| t.name == TARGET_NAME }
  target.remove_from_project
end

# Get reference to Sentry target to copy settings from
sentry_target = project.targets.find { |t| t.name == 'Sentry' }
unless sentry_target
  puts "ERROR: Could not find 'Sentry' target"
  exit 1
end

puts "Creating new framework target: #{TARGET_NAME}"

# Create new framework target
target = project.new_target(:framework, TARGET_NAME, :ios, '12.0')

# Copy build configurations from Sentry target
sentry_target.build_configurations.each do |sentry_config|
  target_config = target.build_configurations.find { |c| c.name == sentry_config.name }
  next unless target_config

  # Copy relevant build settings
  settings_to_copy = %w[
    CLANG_ENABLE_MODULES
    ALWAYS_SEARCH_USER_PATHS
    CLANG_CXX_LANGUAGE_STANDARD
    CLANG_ENABLE_OBJC_ARC
    GCC_C_LANGUAGE_STANDARD
    ENABLE_STRICT_OBJC_MSGSEND
    IPHONEOS_DEPLOYMENT_TARGET
    MACOSX_DEPLOYMENT_TARGET
    TVOS_DEPLOYMENT_TARGET
    WATCHOS_DEPLOYMENT_TARGET
    XROS_DEPLOYMENT_TARGET
    CURRENT_PROJECT_VERSION
    MARKETING_VERSION
  ]

  settings_to_copy.each do |key|
    if sentry_config.build_settings[key]
      target_config.build_settings[key] = sentry_config.build_settings[key]
    end
  end

  # Set SentryObjC-specific settings
  target_config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  target_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'io.sentry.SentryObjC'
  target_config.build_settings['INFOPLIST_FILE'] = 'Sources/SentryObjC/Info.plist'
  target_config.build_settings['DEFINES_MODULE'] = 'YES'
  target_config.build_settings['PRODUCT_MODULE_NAME'] = 'SentryObjC'
  target_config.build_settings['MODULEMAP_FILE'] = 'Sources/SentryObjC/Public/module.modulemap'
  target_config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = ''
  target_config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  target_config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
  target_config.build_settings['SKIP_INSTALL'] = 'NO'
  target_config.build_settings['SWIFT_VERSION'] = '5.0'

  # Header search paths
  target_config.build_settings['HEADER_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SRCROOT)/Sources/SentryObjC/Public',
  ]

  # Set public headers path
  target_config.build_settings['PUBLIC_HEADERS_FOLDER_PATH'] = '$(CONTENTS_FOLDER_PATH)/Headers'
end

# Create or find source groups
puts "Adding source files..."

# Find or create SentryObjC group - use SOURCE_ROOT relative paths
main_group = project.main_group

# Create new groups with SOURCE_ROOT source tree for absolute paths
sentryobjc_group = main_group.new_group('SentryObjC', 'Sources/SentryObjC', :group)
sentryobjc_group.source_tree = 'SOURCE_ROOT'

sentryobjc_public_group = main_group.new_group('SentryObjC/Public', 'Sources/SentryObjC/Public', :group)
sentryobjc_public_group.source_tree = 'SOURCE_ROOT'

sentryobjcbridge_group = main_group.new_group('SentryObjCBridge', 'Sources/SentryObjCBridge', :group)
sentryobjcbridge_group.source_tree = 'SOURCE_ROOT'

# Add ObjC source files
OBJC_SOURCES.each do |file|
  filename = File.basename(file)
  file_ref = sentryobjc_group.new_reference(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "  Added source: #{file}"
end

# Add ObjC headers (public)
OBJC_HEADERS.each do |file|
  filename = File.basename(file)
  if file.include?('/Public/')
    file_ref = sentryobjc_public_group.new_reference(filename)
    # Add to headers build phase as public
    header_file = target.headers_build_phase.add_file_reference(file_ref)
    header_file.settings = { 'ATTRIBUTES' => ['Public'] }
    puts "  Added public header: #{file}"
  else
    file_ref = sentryobjc_group.new_reference(filename)
    # Add to headers build phase as project
    header_file = target.headers_build_phase.add_file_reference(file_ref)
    header_file.settings = { 'ATTRIBUTES' => ['Project'] }
    puts "  Added project header: #{file}"
  end
end

# Add Swift bridge files
SWIFT_SOURCES.each do |file|
  filename = File.basename(file)
  file_ref = sentryobjcbridge_group.new_reference(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "  Added Swift source: #{file}"
end

# Add system frameworks
puts "Adding system frameworks..."
frameworks_group = project.main_group.find_subpath('Frameworks', false) || project.main_group.new_group('Frameworks')

system_frameworks = %w[Foundation]
system_frameworks.each do |framework_name|
  framework_ref = frameworks_group.new_reference("System/Library/Frameworks/#{framework_name}.framework")
  framework_ref.source_tree = 'SDKROOT'
  target.frameworks_build_phase.add_file_reference(framework_ref)
  puts "  Added #{framework_name}.framework"
end

# Add dependency on Sentry target
puts "Adding Sentry target dependency..."
target.add_dependency(sentry_target)

# Link Sentry.framework
sentry_product = sentry_target.product_reference
if sentry_product
  target.frameworks_build_phase.add_file_reference(sentry_product)
  puts "  Added Sentry.framework dependency"
end

# Save project
puts "Saving project..."
project.save

puts "Done! Target '#{TARGET_NAME}' has been added to #{PROJECT_PATH}"
puts ""
puts "Next steps:"
puts "1. Create Sources/SentryObjC/Info.plist if it doesn't exist"
puts "2. Verify the target builds: xcodebuild -project Sentry.xcodeproj -scheme SentryObjC -sdk iphonesimulator build"
puts "3. Build xcframework: ./scripts/build-xcframework-variant.sh SentryObjC '' mh_dylib '' iOSOnly ''"
