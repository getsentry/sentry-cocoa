# ============================================================================
# SENTRY COCOA SDK MAKEFILE
# ============================================================================
# This Makefile provides automation for building, testing, and developing
# the Sentry Cocoa SDK. Run 'make help' to see all available commands.
# ============================================================================

.DEFAULT_GOAL := help

# ============================================================================
# CONFIGURATION
# ============================================================================

# Xcode scheme used to build Sentry SDK
XCODE_SCHEME = Sentry

# iOS Simulator OS version (defaults to '18.4', can be overridden via IOS_SIMULATOR_OS=latest)
IOS_SIMULATOR_OS ?= 18.4

# iOS Simulator device name (defaults to 'iPhone 16 Pro', can be overridden via IOS_DEVICE_NAME='iPhone 15 Pro')
IOS_DEVICE_NAME ?= iPhone 16 Pro

# tvOS Simulator OS version (defaults to 'latest', can be overridden via TVOS_SIMULATOR_OS=18.5)
TVOS_SIMULATOR_OS ?= latest

# tvOS Simulator device name (defaults to 'Apple TV', can be overridden via TVOS_DEVICE_NAME='Apple TV 4K')
TVOS_DEVICE_NAME ?= Apple TV

# visionOS Simulator OS version (defaults to 'latest', can be overridden via VISIONOS_SIMULATOR_OS=2.0)
VISIONOS_SIMULATOR_OS ?= latest

# visionOS Simulator device name (defaults to 'Apple Vision Pro', can be overridden via VISIONOS_DEVICE_NAME='Apple Vision Pro')
VISIONOS_DEVICE_NAME ?= Apple Vision Pro

# watchOS Simulator OS version (defaults to 'latest', can be overridden via WATCHOS_SIMULATOR_OS=11.0)
WATCHOS_SIMULATOR_OS ?= latest

# watchOS Simulator device name (defaults to 'Apple Watch Series 11 (46mm)', can be overridden via WATCHOS_DEVICE_NAME='Apple Watch SE 3 (44mm)')
WATCHOS_DEVICE_NAME ?= Apple Watch Series 11 (46mm)

# Current git reference name
GIT-REF := $(shell git rev-parse --abbrev-ref HEAD)

# ============================================================================
# SETUP
# ============================================================================

## Setup the project by installing dependencies, pre-commit hooks, rbenv, and bundler
#
# Sets up a fresh machine for development by chaining the install tasks.
# Safe to re-run if you need to reinitialize dependencies or hooks.
.PHONY: init
init: init-local init-ci-build init-ci-format

## Setup local development environment
#
# Installs Homebrew, dependencies, pre-commit hooks, rbenv, bundler, and updates tooling versions.
.PHONY: init-local
init-local:
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
	pre-commit install
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle install
	# Install the tools needed to update tooling versions locally
	"$(MAKE)" init-ci-format
	./scripts/update-tooling-versions.sh

## Install CI build dependencies
#
# Installs tools needed for CI build tasks using Brewfile-ci-build.
.PHONY: init-ci-build
init-ci-build:
	brew bundle --file Brewfile-ci-build

## Install CI format dependencies
#
# Installs tools needed to run CI format tasks locally using Brewfile-ci-format.
.PHONY: init-ci-format
init-ci-format:
	brew bundle --file Brewfile-ci-format

## Update tooling versions
#
# Updates tooling versions to match CI requirements.
.PHONY: update-versions
update-versions:
	./scripts/update-tooling-versions.sh

## Check tooling versions
#
# Verifies that local tooling versions match CI requirements.
.PHONY: check-versions
check-versions:
	./scripts/check-tooling-versions.sh

# ============================================================================
# BUILDING
# ============================================================================

## Build all platforms
#
# Convenience target that invokes all platform build targets.
# See build-ios, build-macos, build-catalyst, build-tvos, build-visionos, build-watchos for more details.
.PHONY: build
build: build-ios build-macos build-catalyst build-tvos build-visionos build-watchos

## Build iOS target
#
# Builds the Sentry SDK for iOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-ios
build-ios:
	@echo "--> Building for iOS"
	./scripts/sentry-xcodebuild.sh \
		--platform iOS \
		--os $(IOS_SIMULATOR_OS) \
		--device "$(IOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command build \
		--configuration Debug

## Build macOS target
#
# Builds the Sentry SDK for macOS.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-macos
build-macos:
	@echo "--> Building for macOS"
	./scripts/sentry-xcodebuild.sh \
		--platform macOS \
		--os latest \
		--ref $(GIT-REF) \
		--command build \
		--configuration Debug

## Build Catalyst target
#
# Builds the Sentry SDK for Mac Catalyst.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-catalyst
build-catalyst:
	@echo "--> Building for Catalyst"
	./scripts/sentry-xcodebuild.sh \
		--platform Catalyst \
		--os latest \
		--ref $(GIT-REF) \
		--command build \
		--configuration Debug

## Build tvOS target
#
# Builds the Sentry SDK for tvOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-tvos
build-tvos:
	@echo "--> Building for tvOS"
	./scripts/sentry-xcodebuild.sh \
		--platform tvOS \
		--os $(TVOS_SIMULATOR_OS) \
		--device "$(TVOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command build \
		--configuration Debug

## Build visionOS target
#
# Builds the Sentry SDK for visionOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-visionos
build-visionos:
	@echo "--> Building for visionOS"
	./scripts/sentry-xcodebuild.sh \
		--platform visionOS \
		--os $(VISIONOS_SIMULATOR_OS) \
		--device "$(VISIONOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command build \
		--configuration Debug

## Build watchOS target
#
# Builds the Sentry SDK for watchOS Simulator.
# Note: Tests are not available for watchOS as XCTest is not supported on watchOS.
# Outputs logs and uses xcbeautify for formatted output.
.PHONY: build-watchos
build-watchos:
	@echo "--> Building for watchOS"
	set -o pipefail && NSUnbufferedIO=YES xcrun xcodebuild build \
		-workspace Sentry.xcworkspace \
		-scheme $(XCODE_SCHEME) \
		-destination 'platform=watchOS Simulator,OS=$(WATCHOS_SIMULATOR_OS),name=$(WATCHOS_DEVICE_NAME)' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED="NO" 2>&1 | xcbeautify --preserve-unbeautified

## Build XCFramework for distribution
#
# Creates Sentry XCFramework bundles for all platforms and variants.
# Outputs logs to build-xcframework.log.
.PHONY: build-xcframework
build-xcframework:
	@echo "--> Creating Sentry xcframework"
	./scripts/build-xcframework-local.sh | tee build-xcframework.log

## Build signed XCFramework for distribution
#
# Creates signed Sentry XCFramework bundles for all platforms and variants.
# Outputs logs to build-xcframework.log.
.PHONY: build-signed-xcframework
build-signed-xcframework:
	@echo "--> Creating Signed Sentry xcframework"
	./scripts/build-xcframework-local.sh | tee build-xcframework.log

## Build XCFramework validation sample
#
# Builds the XCFramework validation sample project to verify XCFramework integration.
.PHONY: build-xcframework-sample
build-xcframework-sample:
	xcodebuild -project "Samples/XCFramework-Validation/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

# ============================================================================
# TESTING
# ============================================================================

## Run all platform tests
#
# Convenience target that invokes all platform test targets.
# Note: test-watchos is excluded as watchOS does not support XCTest.
# See test-ios, test-macos, test-catalyst, test-tvos, test-visionos for more details.
.PHONY: test
test: test-ios test-macos test-catalyst test-tvos test-visionos

## Run iOS tests
#
# Runs unit tests for iOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
#
# Optional: ONLY_TESTING=ClassName to run specific test class(es)
# Examples:
#   make test-ios
#   make test-ios ONLY_TESTING=SentryHttpTransportTests
#   make test-ios ONLY_TESTING=SentryHttpTransportTests,SentryHubTests
#   make test-ios ONLY_TESTING=SentryHttpTransportTests/testFlush_WhenNoInternet
.PHONY: test-ios
test-ios:
	@echo "--> Running iOS tests"
	@EXTRA_ARGS=""; \
	if [ -n "$(ONLY_TESTING)" ]; then \
		EXTRA_ARGS="--only-testing $(ONLY_TESTING)"; \
	fi; \
	./scripts/sentry-xcodebuild.sh \
		--platform iOS \
		--os $(IOS_SIMULATOR_OS) \
		--device "$(IOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command test \
		--configuration Test \
		$$EXTRA_ARGS

## Run macOS tests
#
# Runs unit tests for macOS.
# Outputs logs and uses xcbeautify for formatted output.
#
# Optional: ONLY_TESTING=ClassName to run specific test class(es)
# Examples:
#   make test-macos
#   make test-macos ONLY_TESTING=SentryHttpTransportTests
.PHONY: test-macos
test-macos:
	@echo "--> Running macOS tests"
	@EXTRA_ARGS=""; \
	if [ -n "$(ONLY_TESTING)" ]; then \
		EXTRA_ARGS="--only-testing $(ONLY_TESTING)"; \
	fi; \
	./scripts/sentry-xcodebuild.sh \
		--platform macOS \
		--os latest \
		--ref $(GIT-REF) \
		--command test \
		--configuration Test \
		$$EXTRA_ARGS

## Run Catalyst tests
#
# Runs unit tests for Mac Catalyst.
# Outputs logs and uses xcbeautify for formatted output.
#
# Optional: ONLY_TESTING=ClassName to run specific test class(es)
# Examples:
#   make test-catalyst
#   make test-catalyst ONLY_TESTING=SentryHttpTransportTests
.PHONY: test-catalyst
test-catalyst:
	@echo "--> Running Catalyst tests"
	@EXTRA_ARGS=""; \
	if [ -n "$(ONLY_TESTING)" ]; then \
		EXTRA_ARGS="--only-testing $(ONLY_TESTING)"; \
	fi; \
	./scripts/sentry-xcodebuild.sh \
		--platform Catalyst \
		--os latest \
		--ref $(GIT-REF) \
		--command test \
		--configuration Test \
		$$EXTRA_ARGS

## Run tvOS tests
#
# Runs unit tests for tvOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
#
# Optional: ONLY_TESTING=ClassName to run specific test class(es)
# Examples:
#   make test-tvos
#   make test-tvos ONLY_TESTING=SentryHttpTransportTests
.PHONY: test-tvos
test-tvos:
	@echo "--> Running tvOS tests"
	@EXTRA_ARGS=""; \
	if [ -n "$(ONLY_TESTING)" ]; then \
		EXTRA_ARGS="--only-testing $(ONLY_TESTING)"; \
	fi; \
	./scripts/sentry-xcodebuild.sh \
		--platform tvOS \
		--os $(TVOS_SIMULATOR_OS) \
		--device "$(TVOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command test \
		--configuration Test \
		$$EXTRA_ARGS

## Run visionOS tests
#
# Runs unit tests for visionOS Simulator.
# Outputs logs and uses xcbeautify for formatted output.
#
# Optional: ONLY_TESTING=ClassName to run specific test class(es)
# Examples:
#   make test-visionos
#   make test-visionos ONLY_TESTING=SentryHttpTransportTests
.PHONY: test-visionos
test-visionos:
	@echo "--> Running visionOS tests"
	@EXTRA_ARGS=""; \
	if [ -n "$(ONLY_TESTING)" ]; then \
		EXTRA_ARGS="--only-testing $(ONLY_TESTING)"; \
	fi; \
	./scripts/sentry-xcodebuild.sh \
		--platform visionOS \
		--os $(VISIONOS_SIMULATOR_OS) \
		--device "$(VISIONOS_DEVICE_NAME)" \
		--ref $(GIT-REF) \
		--command test \
		--configuration Test \
		$$EXTRA_ARGS

# Note: test-watchos target is not available because watchOS does not support XCTest.
# Tests cannot be run on watchOS as the XCTest framework is not available on that platform.

## Run test server in background
#
# Builds and runs the test server in the background for integration testing.
# Saves the process ID to test-server/.test-server.pid for safe shutdown.
.PHONY: run-test-server
run-test-server:
	cd ./test-server && swift build
	cd ./test-server && { swift run & echo $$! > .test-server.pid; }

## Run test server synchronously
#
# Builds and runs the test server synchronously (blocks until stopped).
.PHONY: run-test-server-sync
run-test-server-sync:
	cd ./test-server && swift build
	cd ./test-server && swift run

## Stop test server
#
# Stops the test server using the saved process ID from test-server/.test-server.pid.
# This is safer than killing by port as it only stops the test server process.
.PHONY: stop-test-server
stop-test-server:
	@if [ -f test-server/.test-server.pid ]; then \
		pid=$$(cat test-server/.test-server.pid); \
		if ps -p $$pid > /dev/null 2>&1; then \
			kill $$pid && echo "Test server (PID $$pid) stopped"; \
			rm test-server/.test-server.pid; \
		else \
			echo "Test server PID $$pid not running (cleaning up PID file)"; \
			rm test-server/.test-server.pid; \
		fi \
	else \
		echo "No PID file found. Test server may not be running."; \
	fi

## Run critical UI tests
#
# Runs important UI test suites for validation.
.PHONY: test-ui-critical
test-ui-critical:
	./scripts/test-ui-critical.sh

# ============================================================================
# LINTING & FORMATTING
# ============================================================================

# Get staged Swift files
STAGED_SWIFT_FILES := $(shell git diff --cached --diff-filter=d --name-only | grep '\.swift$$' | awk '{printf "\"%s\" ", $$0}')

## Run linting checks on all files
#
# Runs SwiftLint, Clang-Format checks, Objective-C id usage checks, and dprint checks without modifying files.
.PHONY: lint
lint:
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	ruby ./scripts/check-objc-id-usage.rb -r Sources/Sentry
	swiftlint --strict --quiet
	dprint check "**/*.{md,json,yaml,yml}"

## Run linting checks on staged files only
#
# Runs SwiftLint, Clang-Format checks, Objective-C id usage checks, and dprint checks on staged files only.
.PHONY: lint-staged
lint-staged:
	@echo "--> Running Swiftlint and Clang-Format on staged files"
	./scripts/check-clang-format.py -r Sources Tests
	ruby ./scripts/check-objc-id-usage.rb -r Sources/Sentry
	swiftlint --strict --quiet $(STAGED_SWIFT_FILES)
	dprint check "**/*.{md,json,yaml,yml}"

## Format all files
#
# Runs all formatting tasks for Swift, Objective-C, Markdown, JSON, and YAML files.
.PHONY: format
format: format-clang format-swift-all format-markdown format-json format-yaml

## Format Objective-C, C, and C++ files
#
# Formats all Objective-C, Objective-C++, C, and C++ files using clang-format.
.PHONY: format-clang
format-clang:
	@find . -type f \( -name "*.h" -or -name "*.hpp" -or -name "*.c" -or -name "*.cpp" -or -name "*.m" -or -name "*.mm" \) -and \
		! \( -path "**.build/*" -or -path "**Build/*"  -or -path "**/libs/**" -or -path "**/Pods/**" -or -path "**/*.xcarchive/*" \) \
		| xargs clang-format -i -style=file

## Format all Swift files
#
# Formats all Swift files using SwiftLint auto-fix.
.PHONY: format-swift-all
format-swift-all:
	@echo "Running swiftlint --fix on all files"
	swiftlint --fix --quiet

## Format staged Swift files
#
# Formats only staged Swift files using SwiftLint auto-fix.
.PHONY: format-swift-staged
format-swift-staged:
	@echo "Running swiftlint --fix on staged files"
	swiftlint --fix --quiet $(STAGED_SWIFT_FILES)

## Format Markdown files
#
# Formats all Markdown files using dprint.
.PHONY: format-markdown
format-markdown:
	dprint fmt "**/*.md"

## Format JSON files
#
# Formats all JSON files using dprint.
.PHONY: format-json
format-json:
	dprint fmt "**/*.json"

## Format YAML files
#
# Formats all YAML and YML files using dprint.
.PHONY: format-yaml
format-yaml:
	dprint fmt "**/*.{yaml,yml}"

# ============================================================================
# ANALYSIS
# ============================================================================

## Run static analysis
#
# Runs Xcode's static analyzer and reports any issues found.
# Outputs HTML reports to the analyzer directory.
.PHONY: analyze
analyze:
	rm -rf analyzer
	set -o pipefail && NSUnbufferedIO=YES xcodebuild analyze \
		-workspace Sentry.xcworkspace \
		-scheme Sentry \
		-configuration Release \
		CLANG_ANALYZER_OUTPUT=html \
		CLANG_ANALYZER_OUTPUT_DIR=analyzer \
		CODE_SIGNING_ALLOWED="NO" 2>&1 | xcbeautify --preserve-unbeautified
	@if [[ -n `find analyzer -name "*.html"` ]]; then \
		echo "Analyzer found issues:"; \
		find analyzer -name "*.html"; \
		exit 1; \
	fi

# ============================================================================
# CODE GENERATION
# ============================================================================

## Generate public API documentation
#
# Updates the public API documentation from source code.
.PHONY: generate-public-api
generate-public-api:
	./scripts/update-api.sh

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

## Remove expectedSignature attributes from XCFramework project
#
# Removes expectedSignature attributes from XCFramework project for CI builds.
# These attributes are developer-specific and cause issues in CI environments.
.PHONY: strip-xcframework-expected-signature
strip-xcframework-expected-signature:
	sed -i '' 's/expectedSignature = "[^"]*"; //g' Samples/XCFramework-Validation/XCFramework.xcodeproj/project.pbxproj

## Bump version to specified version
#
# Updates the version across all project files.
# Usage: make bump-version TO=5.0.0-rc.0
.PHONY: bump-version
bump-version: clean-version-bump
	@echo "--> Bumping version to ${TO}"
	./Utils/VersionBump/.build/debug/VersionBump --update ${TO}

## Verify version matches specified version
#
# Verifies that the version matches the specified version across all project files.
# Usage: make verify-version TO=5.0.0-rc.0
.PHONY: verify-version
verify-version: clean-version-bump
	@echo "--> Verifying version ${TO}"
	./Utils/VersionBump/.build/debug/VersionBump --verify ${TO}

## Clean and build VersionBump tool
#
# Cleans and rebuilds the VersionBump utility tool.
.PHONY: clean-version-bump
clean-version-bump:
	@echo "--> Clean VersionBump"
	cd Utils/VersionBump && rm -rf .build && swift build

## Release new version
#
# Bumps version, commits changes, creates tag, and pushes to remote.
# Usage: make release TO=5.0.0-rc.0
.PHONY: release
release: bump-version git-commit-add

## Commit version changes and create tag
#
# Commits version changes, creates git tag, and pushes to remote.
# Usage: make git-commit-add TO=5.0.0-rc.0
.PHONY: git-commit-add
git-commit-add:
	@echo "\n\n\n--> Committing git ${TO}"
	git commit -am "release: ${TO}"
	git tag ${TO}
	git push
	git push --tags

# ============================================================================
# VALIDATION
# ============================================================================

## Lint CocoaPods podspec
#
# Validates the CocoaPods podspec file.
.PHONY: pod-lint
pod-lint:
	@echo "--> Build local pod"
	pod lib lint --verbose

# ============================================================================
# XCODE PROJECT GENERATION
# ============================================================================

## Generate Xcode projects and open workspace
#
# Generates all sample Xcode projects and opens the workspace in Xcode.
.PHONY: xcode
xcode: xcode-ci
	open Sentry.xcworkspace

## Generate all sample Xcode projects
#
# Generates Xcode projects for all sample apps using xcodegen.
.PHONY: xcode-ci
xcode-ci:
	xcodegen --spec Samples/SPM/SPM.yml
	xcodegen --spec Samples/SentrySampleShared/SentrySampleShared.yml
	xcodegen --spec Samples/SessionReplay-CameraTest/SessionReplay-CameraTest.yml
	xcodegen --spec Samples/iOS-ObjectiveC/iOS-ObjectiveC.yml
	xcodegen --spec Samples/iOS-Swift/iOS-Swift.yml
	xcodegen --spec Samples/iOS-Swift6/iOS-Swift6.yml
	xcodegen --spec Samples/iOS-SwiftUI/iOS-SwiftUI.yml
	xcodegen --spec Samples/iOS-SwiftUI-Widgets/iOS-SwiftUI-Widgets.yml
	xcodegen --spec Samples/iOS15-SwiftUI/iOS15-SwiftUI.yml
	xcodegen --spec Samples/macOS-SwiftUI/macOS-SwiftUI.yml
	xcodegen --spec Samples/macOS-Swift/macOS-Swift.yml
	xcodegen --spec Samples/tvOS-Swift/tvOS-Swift.yml
	xcodegen --spec Samples/visionOS-Swift/visionOS-Swift.yml
	xcodegen --spec Samples/watchOS-Swift/watchOS-Swift.yml
	xcodegen --spec TestSamples/SwiftUITestSample/SwiftUITestSample.yml
	xcodegen --spec TestSamples/SwiftUICrashTest/SwiftUICrashTest.yml
	xcodegen --spec Samples/DistributionSample/DistributionSample.yml
	xcodegen --spec Samples/SDK-Size/SDK-Size.yml

# ============================================================================
# HELP & DOCUMENTATION
# ============================================================================

# Reusable awk script for detailed help output
define HELP_DETAIL_AWK
BEGIN { summary = ""; detailsCount = 0; printed = 0; lookingForDeps = 0 } \
/^## / { summary = substr($$0, 4); delete details; detailsCount = 0; next } \
/^#($$| )/ { \
	if (summary != "") { \
		line = $$0; \
		if (substr(line,1,2)=="# ") detailLine = substr(line,3); else detailLine = ""; \
		details[detailsCount++] = detailLine; \
	} \
	if (lookingForDeps && $$0 !~ /^#/) { lookingForDeps = 0 } \
	next \
} \
/^\.PHONY: / && summary != "" { \
	for (i = 2; i <= NF; i++) { \
		if ($$i == T) { \
			found = 1; \
			lookingForDeps = 1; \
			break \
		} \
	} \
	if (!found) { summary = ""; detailsCount = 0; delete details } \
	next \
} \
lookingForDeps && /^[A-Za-z0-9_.-]+[ \t]*:/ && $$0 !~ /^\.PHONY:/ && $$0 !~ /^\t/ && index($$0,"=")==0 { \
	raw = $$0; \
	split(raw, parts, ":"); \
	tn = parts[1]; \
	if (tn == T) { \
		depStr = substr(raw, index(raw, ":")+1); \
		gsub(/^[ \t]+|[ \t]+$$/, "", depStr); \
		firstDep = depStr; \
		split(depStr, depParts, /[ \t]+/); \
		if (length(depParts[1]) > 0) firstDep = depParts[1]; \
		lookingForDeps = 0; \
	} \
	next \
} \
found && !lookingForDeps { \
	printf "%s\n\n", summary; \
	for (j = 0; j < detailsCount; j++) { \
		if (length(details[j]) > 0) printf "%s\n", details[j]; else print ""; \
	} \
	print ""; \
	printf "Usage:\n"; \
	printf "  make %s\n", T; \
	printed = 1; \
	found = 0; summary = ""; detailsCount = 0; delete details; firstDep = ""; \
	next \
} \
END { if (!printed) { printf "No detailed help found for target: %s\n", T } }
endef

## Show this help message with all available commands
#
# Displays a formatted list of all available make targets with descriptions.
# Commands are organized by topic for easy navigation.
.PHONY: help
help:
	@if [ -n "$(name)" ]; then \
		"$(MAKE)" --no-print-directory help-target name="$(name)"; \
	else \
		echo "=============================================="; \
		echo "🚀 SENTRY COCOA SDK DEVELOPMENT COMMANDS"; \
		echo "=============================================="; \
		echo ""; \
		awk 'BEGIN { summary = ""; n = 0; maxlen = 0 } \
		/^## / { summary = substr($$0, 4); delete details; detailsCount = 0; next } \
		/^\.PHONY: / && summary != "" { \
			for (i = 2; i <= NF; i++) { \
				targets[n] = $$i; \
				summaries[n] = summary; \
				if (length($$i) > maxlen) maxlen = length($$i); \
				n++; \
			} \
			summary = ""; next \
		} \
		END { \
			for (i = 0; i < n; i++) { \
				printf "\033[36m%-*s\033[0m %s\n", maxlen, targets[i], summaries[i]; \
			} \
		}' $(MAKEFILE_LIST); \
		echo ""; \
		echo "💡 Use 'make <command>' to run any command above."; \
		echo "📖 For detailed help on a command, run: make help-<command>  (e.g., make help-build-ios)"; \
		echo "📖 Or: make help name=<command>      (e.g., make help name=build-ios)"; \
		echo ""; \
	fi
 
.PHONY: help-% help-target
help-%:
	@target="$*"; \
	awk -v T="$$target" '$(HELP_DETAIL_AWK)' $(MAKEFILE_LIST)

help-target:
	@[ -n "$(name)" ] || { echo "Usage: make help name=<target>"; exit 1; }; \
	awk -v T="$(name)" '$(HELP_DETAIL_AWK)' $(MAKEFILE_LIST)
