init:
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle update

lint:
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	swiftlint
.PHONY: lint

# Format all h,c,cpp and m files
format:
	@find . -type f \( -name "*.h" -or -name "*.hpp" -or -name "*.c" -or -name "*.cpp" -or -name "*.m" -or -name "*.mm" \) -and \
		! \( -path "**.build/*" -or -path "**/libs/**" \) \
		| xargs clang-format -i -style=file
	
	swiftlint autocorrect
.PHONY: format

test:
	@echo "--> Running all tests"
	xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Test GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES -destination "platform=macOS" test | rbenv exec bundle exec xcpretty -t
.PHONY: test

run-test-server:
	cd ./test-server && swift build 
	cd ./test-server && swift run &
.PHONY: run-test-server

analyze:
	rm -r analyzer
	xcodebuild analyze -workspace Sentry.xcworkspace -scheme Sentry -configuration Release CLANG_ANALYZER_OUTPUT=html CLANG_ANALYZER_OUTPUT_DIR=analyzer | rbenv exec bundle exec xcpretty -t

# Since Carthage 0.38.0 we need to create separate .framework.zip and .xcframework.zip archives.
# After creating the zips we create a JSON to be able to test Carthage locally.
# For more info check out: https://github.com/Carthage/Carthage/releases/tag/0.38.0
build-xcframework:
	@echo "--> Carthage: creating Sentry xcframework"
	carthage build --use-xcframeworks --no-skip-current
# use ditto here to avoid clobbering symlinks which exist in macOS frameworks
	ditto -c -k -X --rsrc --keepParent Carthage Sentry.xcframework.zip

build-xcframework-sample:
	./scripts/create-carthage-json.sh
	cd Samples/Carthage-Validation/XCFramework/ && carthage update --use-xcframeworks
	xcodebuild -project "Samples/Carthage-Validation/XCFramework/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

# Building the .frameworsk.zip only works with Xcode 12, as there is no workaround yet for Xcode 13.
build-framework:
	@echo "--> Carthage: creating Sentry framework"
	./scripts/carthage-xcode12-workaround.sh build --no-skip-current
	./scripts/carthage-xcode12-workaround.sh archive Sentry --output Sentry.framework.zip

build-framework-sample:
	./scripts/create-carthage-json.sh
	cd Samples/Carthage-Validation/Framework/ && carthage update
	xcodebuild -project "Samples/Carthage-Validation/Framework/Framework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

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
	pod trunk push Sentry.podspec
