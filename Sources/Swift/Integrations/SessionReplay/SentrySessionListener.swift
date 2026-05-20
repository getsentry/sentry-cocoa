// swiftlint:disable missing_docs
@objc
@_spi(Private) public protocol SentrySessionListener {
    /// Called on the main thread when a session ends.
    @objc(sentrySessionEndedWithSession:) func sentrySessionEnded(session: SentrySession)
    /// Called on the main thread when a session starts.
    @objc(sentrySessionStartedWithSession:) func sentrySessionStarted(session: SentrySession)
}
// swiftlint:enable missing_docs
