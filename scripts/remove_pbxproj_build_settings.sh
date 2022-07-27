#!/usr/bin/env bash

# We want to keep all build settings inside xcconfig files and leave nothing in the Xcode project, as this allows for better organization and also because we don't check in the Xcode project. However, it's not possible to generate an Xcode project with XcodeGen that contains absolutely no build settings in the pbxproj file. There are always a minimum of "default" settings. See https://github.com/yonaskolb/XcodeGen/issues/553. This script removes all such settings from the pbxproj file after it's generated by XcodeGen.

xcode_project="${1}"
pbxproj_file="${xcode_project}/project.pbxproj"

perl -0pe 's/buildSettings = \{[^}]*\};/buildSettings = \{\};/gms' "${pbxproj_file}" > fixed.pbxproj
mv fixed.pbxproj "${pbxproj_file}"
