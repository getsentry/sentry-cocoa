@objc
@_spi(Private) public protocol SentrySessionListener {
    @objc func sentrySessionEnded(session: SentrySession)
    @objc func sentrySessionStarted(session: SentrySession)
}
