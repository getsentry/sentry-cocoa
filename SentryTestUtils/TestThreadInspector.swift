import Foundation

public class TestThreadInspector: SentryThreadInspector {
    
    public var allThreads: [SentryThread]?
    
    public static var instance: TestThreadInspector {
        // We need something to pass to the super initializer, because the empty initializer has been marked unavailable.
        let inAppLogic = SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])
        let crashStackEntryMapper = SentryCrashStackEntryMapper(inAppLogic: inAppLogic)
        let stacktraceBuilder = SentryStacktraceBuilder(crashStackEntryMapper: crashStackEntryMapper)
        return TestThreadInspector(stacktraceBuilder: stacktraceBuilder, andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper())
    }

    public override func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        return allThreads?.first?.stacktrace ?? TestData.thread.stacktrace
    }
    
    public override func getCurrentThreads() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

    public override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

}
