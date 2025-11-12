@_spi(Private) @testable import Sentry

final class SentryTestSessionDelegate: NSObject, SentrySessionDelegate {
    private let handler: () -> SentrySession?

    init(handler: @escaping () -> SentrySession?) {
        self.handler = handler
    }

    func incrementSessionErrors() -> SentrySession? {
        handler()
    }
}
