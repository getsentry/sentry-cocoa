@_spi(Private) @testable import Sentry
import Foundation

class TestDefaultThreadInspector: SentryDefaultThreadInspector {

    var allThreads: [SentryThread]?
    var getCurrentThreadsInvocations = 0
    var getCurrentThreadsWithStackTraceInvocations = 0

    static var instance: TestDefaultThreadInspector {
        // We need something to pass to the super initializer, because the empty initializer has been marked unavailable.
        let inAppLogic = SentryInAppLogic(inAppIncludes: [])
        let crashStackEntryMapper = SentryCrashStackEntryMapper(inAppLogic: inAppLogic)
        let stacktraceBuilder = SentryStacktraceBuilder(crashStackEntryMapper: crashStackEntryMapper)
        #if SDK_V10
        return TestDefaultThreadInspector(stacktraceBuilder: stacktraceBuilder,
            snapshotProvider: SentrySystemThreadSnapshotProvider(requiresCrashHandler: false))
        #else
        return TestDefaultThreadInspector(stacktraceBuilder: stacktraceBuilder, andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper())
        #endif
    }

    override func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        return allThreads?.first?.stacktrace ?? TestData.thread.stacktrace
    }

    override func getCurrentThreads() -> [SentryThread] {
        getCurrentThreadsInvocations += 1
        return allThreads ?? [TestData.thread]
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        getCurrentThreadsWithStackTraceInvocations += 1
        return allThreads ?? [TestData.thread]
    }

}

class TestThreadInspector: SentryThreadInspector {

    var allThreads: [SentryThread]?

    static var instance: TestThreadInspector {
        return TestThreadInspector(options: SentryDependencyContainer.sharedInstance().startOptions)
    }

    override func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        return allThreads?.first?.stacktrace ?? TestData.thread.stacktrace
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

}
