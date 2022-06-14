import Foundation

class TestThreadInspector: SentryThreadInspector {
    
    var mainThread: SentryCrashThread?
    var allThreds: [Sentry.Thread]?
    
    static var instance: TestThreadInspector {
        // We need something to pass to the super initializer, because the empty initializer has been marked unavailable.
        let inAppLogic = SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])
        let crashStackEntryMapper = SentryCrashStackEntryMapper(inAppLogic: inAppLogic)
        let stacktraceBuilder = SentryStacktraceBuilder(crashStackEntryMapper: crashStackEntryMapper)
        return TestThreadInspector(stacktraceBuilder: stacktraceBuilder, andMachineContextWrapper: SentryCrashDefaultMachineContextWrapper())
    }
    
    override func getCurrentThreads() -> [Sentry.Thread] {
        return allThreds ?? [TestData.thread]
    }

    override func getCurrentThreads(withStackTrace getAllStacktraces: Bool) -> [Sentry.Thread] {
        return allThreds ?? [TestData.thread]
    }
    
    override func isMainThread(_ thread: SentryCrashThread) -> Bool {
        return thread == mainThread
    }
    
}
