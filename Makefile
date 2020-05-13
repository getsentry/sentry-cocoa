lint:
	@echo "--> Running swiftlint"
	./scripts/check-clang-format.py -r .
	swiftlint
.PHONY: lint
	
format:
	@find . -type f \
		-name "*.h" \
		-o -name "*.c" \
		-o -name "*.m" \
		-o -name "*.cpp" \
		| xargs clang-format -i -style=file
.PHONY: format

test:
	@echo "--> Running all tests"
	bundle exec fastlane test
.PHONY: test

build-carthage:
	@echo "--> Creating Sentry framework package with carthage"
	carthage build --no-skip-current
	carthage archive Sentry --output Sentry.framework.zip

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
	pod lib lint --allow-warnings --verbose

git-commit-add:
	@echo "\n\n\n--> Commting git ${TO}"
	git commit -am "release: ${TO}"
	git tag ${TO}
	git push
	git push --tags

release-pod:
	pod trunk push Sentry.podspec
