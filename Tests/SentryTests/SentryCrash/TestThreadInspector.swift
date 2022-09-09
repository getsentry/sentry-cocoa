import Foundation

class TestThreadInspector: SentryThreadInspector {
    
    var allThreads: [SentryThread]?
    
    static var instance: TestThreadInspector {
        // We need something to pass to the super initializer, because the empty initializer has been marked unavailable.
        let inAppLogic = SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])
        let crashStackEntryMapper = SentryCrashStackEntryMapper(inAppLogic: inAppLogic)
        let stacktraceBuilder = SentryStacktraceBuilder(crashStackEntryMapper: crashStackEntryMapper)
        return TestThreadInspector(stacktraceBuilder: stacktraceBuilder, andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper())
    }
    
    override func getCurrentThreads() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return allThreads ?? [TestData.thread]
    }

}
