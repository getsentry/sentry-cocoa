@_spi(Private) import Sentry

let dependencies = SentryDependencyContainer.sharedInstance()
let reporter: SentryCrashSwift = dependencies.crashReporter
let bridge = SentryCrashBridge(
    notificationCenterWrapper: dependencies.notificationCenterWrapper,
    dateProvider: dependencies.dateProvider,
    crashReporter: reporter
)
reporter.setBridge(bridge)
precondition(dependencies.crashWrapper is SentryDefaultCrashReporter)
