.PHONY: init
init: init-local init-ci-build init-ci-deploy init-ci-format

.PHONY: init-local
init-local:
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
	pre-commit install
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle install
	
# Install the tools needed to update tooling versions locally
	$(MAKE) init-ci-format
	./scripts/update-tooling-versions.sh

.PHONY: init-ci-build
init-ci-build:
	brew bundle --file Brewfile-ci-build
	
# installs the tools needed to run CI deploy tasks locally (note that carthage is preinstalled in github actions)
.PHONY: init-ci-deploy
init-ci-deploy:
	brew bundle --file Brewfile-ci-deploy

# installs the tools needed to run CI format tasks locally
.PHONY: init-ci-format
init-ci-format:
	brew bundle --file Brewfile-ci-format

.PHONY: update-versions
update-versions:
	./scripts/update-tooling-versions.sh

.PHONY: check-versions
check-versions:
	./scripts/check-tooling-versions.sh

define run-lint-tools
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	swiftlint --strict $(1)
	dprint check "**/*.{md,json,yaml,yml}"
endef

# Get staged Swift files
STAGED_SWIFT_FILES := $(shell git diff --cached --diff-filter=d --name-only | grep '\.swift$$' | awk '{printf "\"%s\" ", $$0}')

lint:
# calling run-lint-tools with no arguments will run swift lint on all files
	$(call run-lint-tools)
.PHONY: lint

lint-staged:
	$(call run-lint-tools,$(STAGED_SWIFT_FILES))
.PHONY: lint-staged

format: format-clang format-swift-all format-markdown format-json format-yaml

# Format ObjC, ObjC++, C, and C++
format-clang:
	@find . -type f \( -name "*.h" -or -name "*.hpp" -or -name "*.c" -or -name "*.cpp" -or -name "*.m" -or -name "*.mm" \) -and \
		! \( -path "**.build/*" -or -path "**Build/*" -or -path "**/Carthage/Checkouts/*"  -or -path "**/libs/**" -or -path "**/Pods/**" -or -path "**/*.xcarchive/*" \) \
		| xargs clang-format -i -style=file

# Format all Swift files
format-swift-all:
	@echo "Running swiftlint --fix on all files"
	swiftlint --fix

# Format Swift staged files
.PHONY: format-swift-staged
format-swift-staged:
	@echo "Running swiftlint --fix on staged files"
	swiftlint --fix $(STAGED_SWIFT_FILES)

# Format Markdown
format-markdown:
	dprint fmt "**/*.md"

# Format JSON
format-json:
	dprint fmt "**/*.json"

# Format YAML
format-yaml:
	dprint fmt "**/*.{yaml,yml}"

generate-public-api:
	./scripts/update-api.sh

## Current git reference name
GIT-REF := $(shell git rev-parse --abbrev-ref HEAD)

test:
	@echo "--> Running all tests"
	./scripts/sentry-xcodebuild.sh --platform iOS --os latest --ref $(GIT-REF) --command test --configuration Test
	./scripts/xcode-slowest-tests.sh
.PHONY: test

run-test-server:
	cd ./test-server && swift build
	cd ./test-server && swift run &

run-test-server-sync:
	cd ./test-server && swift build
	cd ./test-server && swift run

.PHONY: run-test-server run-test-server-sync

test-alamofire:
	./scripts/test-alamofire.sh

test-homekit:
	./scripts/test-homekit.sh

test-ui-critical:
	./scripts/test-ui-critical.sh

analyze:
	rm -rf analyzer
	set -o pipefail && NSUnbufferedIO=YES xcodebuild analyze -workspace Sentry.xcworkspace -scheme Sentry -configuration Release CLANG_ANALYZER_OUTPUT=html CLANG_ANALYZER_OUTPUT_DIR=analyzer CODE_SIGNING_ALLOWED="NO" 2>&1 | xcbeautify && [[ -z `find analyzer -name "*.html"` ]]

# Since Carthage 0.38.0 we need to create separate .framework.zip and .xcframework.zip archives.
# After creating the zips we create a JSON to be able to test Carthage locally.
# For more info check out: https://github.com/Carthage/Carthage/releases/tag/0.38.0
build-xcframework:
	@echo "--> Carthage: creating Sentry xcframework"
	./scripts/build-xcframework-local.sh | tee build-xcframework.log

build-signed-xcframework:
	@echo "--> Carthage: creating Signed Sentry xcframework"
	./scripts/build-xcframework-local.sh | tee build-xcframework.log

build-xcframework-sample:
	./scripts/create-carthage-json.sh
	cd Samples/Carthage-Validation/XCFramework/ && carthage update --use-xcframeworks
	xcodebuild -project "Samples/Carthage-Validation/XCFramework/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

# call this like `make bump-version TO=5.0.0-rc.0`
bump-version: clean-version-bump
	@echo "--> Bumping version from ${TO}"
	./Utils/VersionBump/.build/debug/VersionBump --update ${TO}

verify-version: clean-version-bump
	@echo "--> Verifying version from ${TO}"
	./Utils/VersionBump/.build/debug/VersionBump --verify ${TO}

clean-version-bump:
	@echo "--> Clean VersionBump"
	cd Utils/VersionBump && rm -rf .build && swift build

release: bump-version git-commit-add
.PHONY: release

pod-lint:
	@echo "--> Build local pod"
	pod lib lint --verbose

git-commit-add:
	@echo "\n\n\n--> Commting git ${TO}"
	git commit -am "release: ${TO}"
	git tag ${TO}
	git push
	git push --tags

release-pod:
	pod trunk push SentryPrivate.podspec
	pod trunk push Sentry.podspec
	pod trunk push SentrySwiftUI.podspec

xcode:
	make xcode-ci
	open Sentry.xcworkspace

xcode-ci:
	xcodegen --spec Samples/SentrySampleShared/SentrySampleShared.yml
	xcodegen --spec Samples/SessionReplay-CameraTest/SessionReplay-CameraTest.yml
	xcodegen --spec Samples/iOS-ObjectiveC/iOS-ObjectiveC.yml
	xcodegen --spec Samples/iOS-Swift/iOS-Swift.yml
	xcodegen --spec Samples/iOS-Swift6/iOS-Swift6.yml
	xcodegen --spec Samples/iOS13-Swift/iOS13-Swift.yml
	xcodegen --spec Samples/iOS-SwiftUI/iOS-SwiftUI.yml
	xcodegen --spec Samples/iOS15-SwiftUI/iOS15-SwiftUI.yml
	xcodegen --spec Samples/macOS-SwiftUI/macOS-SwiftUI.yml
	xcodegen --spec Samples/macOS-Swift/macOS-Swift.yml
	xcodegen --spec Samples/tvOS-Swift/tvOS-Swift.yml
	xcodegen --spec Samples/visionOS-Swift/visionOS-Swift.yml
	xcodegen --spec Samples/watchOS-Swift/watchOS-Swift.yml
	xcodegen --spec TestSamples/SwiftUITestSample/SwiftUITestSample.yml
