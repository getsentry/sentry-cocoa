import Foundation
@_spi(Private) @testable import Sentry

class TestDefaultThreadInspector: SentryDefaultThreadInspector {
    
    var allThreads: [SentryThread]?
    
    static var instance: TestDefaultThreadInspector {
        // We need something to pass to the super initializer, because the empty initializer has been marked unavailable.
        let inAppLogic = SentryInAppLogic(inAppIncludes: [])
        let crashStackEntryMapper = SentryCrashStackEntryMapper(inAppLogic: inAppLogic)
        let stacktraceBuilder = SentryStacktraceBuilder(crashStackEntryMapper: crashStackEntryMapper)
        return TestDefaultThreadInspector(stacktraceBuilder: stacktraceBuilder, andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper(), symbolicate: false)
    }

    override func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        return allThreads?.first?.stacktrace ?? TestData.thread.stacktrace
    }
    
    override func getCurrentThreads() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

}

class TestThreadInspector: SentryThreadInspector {
    
    var allThreads: [SentryThread]?
    
    static var instance: TestThreadInspector {
        return TestThreadInspector()
    }

    override func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        return allThreads?.first?.stacktrace ?? TestData.thread.stacktrace
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

}
