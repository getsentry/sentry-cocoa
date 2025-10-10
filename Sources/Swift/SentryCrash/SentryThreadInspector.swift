@_spi(Private) @objc public protocol SentryThreadInspector {
    func stacktraceForCurrentThreadAsyncUnsafe() -> SentryStacktrace?
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
    func getThreadName(_ thread: UInt) -> String?
}
