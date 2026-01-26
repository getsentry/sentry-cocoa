// swiftlint:disable missing_docs
@objc
@_spi(Private) public protocol SentrySessionListener {
    @objc(sentrySessionEndedWithSession:) func sentrySessionEnded(session: SentrySession)
    @objc(sentrySessionStartedWithSession:) func sentrySessionStarted(session: SentrySession)
}
// swiftlint:enable missing_docs
