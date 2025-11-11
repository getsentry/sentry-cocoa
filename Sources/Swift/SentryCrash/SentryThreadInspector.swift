@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public class SentryThreadInspector: NSObject {
    private let internalHelper: SentryDefaultThreadInspector
    
    override init() {
        internalHelper = SentryDefaultThreadInspector(options: SentrySDKInternal.optionsInternal)
    }

    init(options: Options) {
        internalHelper = SentryDefaultThreadInspector(options: options)
    }

    @objc public func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? {
        internalHelper.stacktraceForCurrentThreadAsyncUnsafe()
    }
    
    @objc public func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        internalHelper.getCurrentThreadsWithStackTrace()
    }
    
    @objc public func getCurrentThreads() -> [SentryThread] {
        internalHelper.getCurrentThreads()
    }
    
    @objc public func getThreadName(_ thread: UInt) -> String? {
        internalHelper.getThreadName(thread)
    }
}
