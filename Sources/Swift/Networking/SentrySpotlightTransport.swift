// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc(SentrySpotlightTransport) public final class SentrySpotlightTransport: NSObject, Transport {

    private let options: Options
    private let requestManager: RequestManager
    private let requestBuilder: SentryNSURLRequestBuilder
    private let apiURL: URL?

    @objc public init(
        options: Options,
        requestManager: RequestManager,
        requestBuilder: SentryNSURLRequestBuilder
    ) {
        self.options = options
        self.requestManager = requestManager
        self.requestBuilder = requestBuilder
        self.apiURL = URL(string: options.spotlightUrl)
        super.init()
    }

    public func send(envelope: SentryEnvelope) {
        guard let apiURL = apiURL else {
            SentrySDKLog.warning("Malformed Spotlight URL passed from the options. Not sending envelope to Spotlight with URL:\(options.spotlightUrl)")
            return
        }

        // Spotlight can only handle the following envelope items.
        // Not removing them leads to an error and events won't get displayed.
        let allowedEnvelopeItems = envelope.items.filter { item in
            item.header.type == SentryEnvelopeItemTypes.event
                || item.header.type == SentryEnvelopeItemTypes.transaction
        }

        let envelopeToSend = SentryEnvelope(header: envelope.header, items: allowedEnvelopeItems)

        let request: URLRequest
        do {
            request = try requestBuilder.createEnvelopeRequest(envelopeToSend, url: apiURL)
        } catch {
            SentrySDKLog.error("Unable to build envelope request with error \(error)")
            return
        }

        requestManager.add(request) { _, error in
            if let error = error {
                SentrySDKLog.error("Error while performing request \(error)")
            }
        }
    }

    public func store(_ envelope: SentryEnvelope) {
        send(envelope: envelope)
    }

    @discardableResult
    public func flush(_ timeout: TimeInterval) -> SentryFlushResult {
        // Empty on purpose
        return .success
    }

    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        // Empty on purpose
    }

    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        // Empty on purpose
    }

    #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    public func setStartFlushCallback(_ callback: @escaping () -> Void) {
        // Empty on purpose
    }
    #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
}
// swiftlint:enable missing_docs
