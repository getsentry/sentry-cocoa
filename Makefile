.PHONY: init
init: setup-git
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle update

.PHONY: init-samples
init-samples: init
	cd Samples/TrendingMovies && carthage update --use-xcframeworks

.PHONY: setup-git
setup-git:
ifneq (, $(shell which pre-commit))
	pre-commit install
endif

lint:
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	swiftlint --strict
.PHONY: lint

no-changes-in-high-risk-files:
	@echo "--> Checking if there are changes in high risk files"
	./scripts/no-changes-in-high-risk-files.sh

format: format-clang format-swift

# Format ObjC, ObjC++, C, and C++
format-clang:
	@find . -type f \( -name "*.h" -or -name "*.hpp" -or -name "*.c" -or -name "*.cpp" -or -name "*.m" -or -name "*.mm" \) -and \
		! \( -path "**.build/*" -or -path "**Build/*" -or -path "**/Carthage/Checkouts/*"  -or -path "**/libs/**" \) \
		| xargs clang-format -i -style=file

# Format Swift
format-swift:
	swiftlint --fix


## Current git reference name
GIT-REF := $(shell git rev-parse --abbrev-ref HEAD)

test:
	@echo "--> Running all tests"
	./scripts/xcode-test.sh iOS latest $(GIT-REF) YES test Test
	./scripts/xcode-slowest-tests.sh
.PHONY: test

run-test-server:
	cd ./test-server && swift build
	cd ./test-server && swift run &
.PHONY: run-test-server

test-alamofire:
	./scripts/test-alamofire.sh

test-homekit:
	./scripts/test-homekit.sh

analyze:
	rm -rf analyzer
	xcodebuild analyze -workspace Sentry.xcworkspace -scheme Sentry -configuration Release CLANG_ANALYZER_OUTPUT=html CLANG_ANALYZER_OUTPUT_DIR=analyzer -destination "platform=iOS Simulator,OS=latest,name=iPhone 11"  CODE_SIGNING_ALLOWED="NO" | xcpretty -t && [[ -z `find analyzer -name "*.html"` ]]

# Since Carthage 0.38.0 we need to create separate .framework.zip and .xcframework.zip archives.
# After creating the zips we create a JSON to be able to test Carthage locally.
# For more info check out: https://github.com/Carthage/Carthage/releases/tag/0.38.0
build-xcframework:
	@echo "--> Carthage: creating Sentry xcframework"
	carthage build --use-xcframeworks --no-skip-current --verbose > build-xcframework.log
# use ditto here to avoid clobbering symlinks which exist in macOS frameworks
	ditto -c -k -X --rsrc --keepParent Carthage Sentry.xcframework.zip

build-xcframework-sample:
	./scripts/create-carthage-json.sh
	cd Samples/Carthage-Validation/XCFramework/ && carthage update --use-xcframeworks
	xcodebuild -project "Samples/Carthage-Validation/XCFramework/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

## Build Sentry as a XCFramework that can be used with watchOS and save it to
## the watchOS sample.
watchOSLibPath = ./Samples/watchOS-Swift/libs
build-for-watchos:
	@echo "--> Building Sentry as a XCFramework that can be used with watchOS"
	rm -rf ${watchOSLibPath}
	xcodebuild archive -scheme Sentry -destination="watchOS" -archivePath ${watchOSLibPath}/watchos.xcarchive -sdk watchos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -scheme Sentry -destination="watch Simulator" -archivePath ${watchOSLibPath}//watchsimulator.xcarchive -sdk watchsimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework -allow-internal-distribution -framework ${watchOSLibPath}/watchos.xcarchive/Products/Library/Frameworks/Sentry.framework -framework ${watchOSLibPath}/watchsimulator.xcarchive/Products/Library/Frameworks/Sentry.framework -output ${watchOSLibPath}//Sentry.xcframework

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
