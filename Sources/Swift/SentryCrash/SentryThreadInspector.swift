// swiftlint:disable missing_docs
internal import _SentryPrivate

#if !ENABLE_KSCRASH

@_spi(Private) @objc public class SentryThreadInspector: NSObject {
    private let internalHelper: SentryDefaultThreadInspector

    override convenience init() {
        self.init(options: SentryDependencyContainer.sharedInstance().startOptions)
    }

    init(options: Options?) {
        internalHelper = SentryDefaultThreadInspector(options: options)
        super.init()
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

#else // ENABLE_KSCRASH

// KSCRASH_TODO: SentryThreadInspector normally wraps SentryDefaultThreadInspector, which is
// compiled out in KSCrash mode (depends on SentryCrashStackCursor_MachineContext from
// Sources/SentryCrash/). Thread inspection — pausing threads to capture stack traces at
// event-capture time — is not yet ported to KSCrash mode.
// Future work: adapt SentryDefaultThreadInspector to use KSCrash's thread introspection.
@_spi(Private) @objc public class SentryThreadInspector: NSObject {
    override init() { super.init() }
    convenience init(options: Options?) { self.init() }

    @objc public func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace? { nil }
    @objc public func getCurrentThreadsWithStackTrace() -> [SentryThread] { [] }
    @objc public func getCurrentThreads() -> [SentryThread] { [] }
    @objc public func getThreadName(_ thread: UInt) -> String? { nil }
}

#endif // ENABLE_KSCRASH
// swiftlint:enable missing_docs
