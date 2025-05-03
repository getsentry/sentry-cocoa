.PHONY: init
init:
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
	pre-commit install
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle install
	./scripts/update-tooling-versions.sh
	yarn install

.PHONY: init-ci-build
init-ci-build:
	brew bundle --file Brewfile-ci-build

.PHONY: init-ci-test
init-ci-test:
	brew bundle --file Brewfile-ci-test
	
# installs the tools needed to run CI deploy tasks locally (note that carthage is preinstalled in github actions)
.PHONY: init-ci-deploy
init-ci-deploy:
	brew bundle --file Brewfile-ci-deploy

# installs the tools needed to run CI format tasks locally
.PHONY: init-ci-format
init-ci-format:
	brew bundle --file Brewfile-ci-format
	rbenv install --skip-existing

.PHONY: update-versions
update-versions:
	./scripts/update-tooling-versions.sh

.PHONY: check-versions
check-versions:
	./scripts/check-tooling-versions.sh

lint:
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	swiftlint --strict
	yarn prettier --check --ignore-unknown --config .prettierrc "**/*.{md,json,yaml,yml}"
.PHONY: lint

format: format-clang format-swift format-markdown format-json format-yaml

# Format ObjC, ObjC++, C, and C++
format-clang:
	@find . -type f \( -name "*.h" -or -name "*.hpp" -or -name "*.c" -or -name "*.cpp" -or -name "*.m" -or -name "*.mm" \) -and \
		! \( -path "**.build/*" -or -path "**Build/*" -or -path "**/Carthage/Checkouts/*"  -or -path "**/libs/**" -or -path "**/Pods/**" -or -path "**/*.xcarchive/*" \) \
		| xargs clang-format -i -style=file

# Format Swift
format-swift:
	swiftlint --fix

# Format Markdown
format-markdown:
	yarn prettier --write --ignore-unknown --config .prettierrc "**/*.md"

# Format JSON
format-json:
	yarn prettier --write --ignore-unknown --config .prettierrc "**/*.json"

# Format YAML
format-yaml:
	yarn prettier --write --ignore-unknown --config .prettierrc "**/*.{yaml,yml}"

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
	./scripts/build-xcframework.sh | tee build-xcframework.log
# use ditto here to avoid clobbering symlinks which exist in macOS frameworks
	ditto -c -k -X --rsrc --keepParent Carthage/Sentry.xcframework Carthage/Sentry.xcframework.zip
	ditto -c -k -X --rsrc --keepParent Carthage/Sentry-Dynamic.xcframework Carthage/Sentry-Dynamic.xcframework.zip
	ditto -c -k -X --rsrc --keepParent Carthage/SentrySwiftUI.xcframework Carthage/SentrySwiftUI.xcframework.zip
	ditto -c -k -X --rsrc --keepParent Carthage/Sentry-WithoutUIKitOrAppKit.xcframework Carthage/Sentry-WithoutUIKitOrAppKit.zip

build-xcframework-sample:
	./scripts/create-carthage-json.sh
	cd Samples/Carthage-Validation/XCFramework/ && carthage update --use-xcframeworks
	xcodebuild -project "Samples/Carthage-Validation/XCFramework/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

# call this like `make bump-version TO=5.0.0-rc.0`
bump-version: clean-version-bump
	@echo "--> Bumping version from ${TO}"
	./Utils/VersionBump/.build/debug/VersionBump ${TO}

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
	xcodegen --spec Samples/SessionReplay-CameraTest/SessionReplay-CameraTest.yml
	xcodegen --spec Samples/iOS-Swift/iOS-Swift.yml
	xcodegen --spec Samples/iOS-Swift6/iOS-Swift6.yml
	xcodegen --spec Samples/iOS13-Swift/iOS13-Swift.yml
	xcodegen --spec Samples/iOS-SwiftUI/iOS-SwiftUI.yml
	xcodegen --spec Samples/iOS15-SwiftUI/iOS15-SwiftUI.yml
	xcodegen --spec Samples/visionOS-Swift/visionOS-Swift.yml
	open Sentry.xcworkspace
