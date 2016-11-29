lint:
	@echo "--> Running swiftlint"
	swiftlint

test:
	@echo "--> Running all tests"
	fastlane test

build-carthage:
	@echo "--> Creating SentrySwift framework package with carthage"
	carthage build --no-skip-current
	carthage archive SentrySwift

release: lint test build-carthage