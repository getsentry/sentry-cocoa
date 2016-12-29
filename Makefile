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

pod-example-projects:
	@echo "--> Running pod install on all example projects"
	pod install --project-directory=Examples/SwiftExample
	pod install --project-directory=Examples/SwiftTVOSExample
	pod install --project-directory=Examples/SwiftWatchOSExample
	pod install --project-directory=Examples/ObjcExample
	pod install --project-directory=Examples/MacExample