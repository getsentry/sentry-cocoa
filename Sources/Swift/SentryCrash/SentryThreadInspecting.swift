@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public protocol SentryThreadInspecting {
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
    func getThreadName(_ thread: UInt) -> String?
}
