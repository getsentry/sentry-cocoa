// swiftlint:disable missing_docs
@_spi(Private) @objc public protocol SentryThreadInspecting {
    func getCurrentThreadsWithStackTrace() -> [SentryThread]
    func getThreadName(_ thread: UInt) -> String?
}
// swiftlint:enable missing_docs
