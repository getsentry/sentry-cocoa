lint:
	@echo "--> Running Swiftlint and Clang-Format"
	./scripts/check-clang-format.py -r Sources Tests
	swiftlint
.PHONY: lint

# Format all h,c,cpp and m files
format:
	@find . -type f \
		-name "*.h" \
		-o -name "*.c" \
		-o -name "*.cpp" \
		-o -name "*.m" \
		| xargs clang-format -i -style=file
	swiftlint autocorrect
.PHONY: format

test:
	@echo "--> Running all tests"
	xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -configuration Debug GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES -destination "platform=macOS" test | xcpretty -t
.PHONY: test

# Since Carthage 0.38.0 we need to create separate .framework.zip and .xcframework.zip archives.
# After creating the zips we create a JSON to be able to test Carthage locally.
# For more info check out: https://github.com/Carthage/Carthage/releases/tag/0.38.0
build-carthage:
	@echo "--> Carthage: creating JSON"
	./scripts/create-carthage-json.sh

	@echo "--> Carthage: creating Sentry xcframework"
	carthage build --use-xcframeworks --no-skip-current
# use ditto here to avoid clobbering symlinks which exist in macOS frameworks
	ditto -c -k -X --rsrc --keepParent Carthage Sentry.xcframework.zip

	@echo "--> Carthage: creating Sentry framework"
	./scripts/carthage-xcode12-workaround.sh build --no-skip-current
	./scripts/carthage-xcode12-workaround.sh archive Sentry --output Sentry.framework.zip

build-carthage-sample-xcframework:
	cd Samples/Carthage-Validation/XCFramework/ && carthage update --use-xcframeworks
	xcodebuild -project "Samples/Carthage-Validation/XCFramework/XCFramework.xcodeproj" -configuration Release CODE_SIGNING_ALLOWED="NO" build

build-carthage-sample-framework:
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
