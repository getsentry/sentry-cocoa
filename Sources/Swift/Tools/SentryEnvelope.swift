// swiftlint:disable missing_docs
internal import _SentryPrivate

@_spi(Private) @objc public final class SentryEnvelope: NSObject {
    
    @objc(initWithId:singleItem:) public convenience init(id: SentryId?, singleItem item: SentryEnvelopeItem) {
        self.init(header: SentryEnvelopeHeader(id: id), singleItem: item)
    }
    
    @objc(initWithHeader:singleItem:) public convenience init(header: SentryEnvelopeHeader, singleItem item: SentryEnvelopeItem) {
        self.init(header: header, items: [item])
    }
    
    @objc(initWithId:items:) public convenience init(id: SentryId?, items: [SentryEnvelopeItem]) {
        self.init(header: SentryEnvelopeHeader(id: id), items: items)
    }
    
    convenience init(session: SentrySession) {
        let item = SentryEnvelopeItem(session: session)
        self.init(header: SentryEnvelopeHeader(id: nil), singleItem: item)
    }
    
    convenience init(sessions: [SentrySession]) {
        let items = sessions.map { SentryEnvelopeItem(session: $0) }
        self.init(header: SentryEnvelopeHeader(id: nil), items: items)
    }
    
    @objc(initWithHeader:items:) public convenience init(header: SentryEnvelopeHeader, items: [SentryEnvelopeItem]) {
        self.init(header: header, items: items, containsCrashEvent: false)
    }

    init(header: SentryEnvelopeHeader, items: [SentryEnvelopeItem], containsCrashEvent: Bool) {
        self.header = header
        self.items = items
        self.containsCrashEvent = containsCrashEvent
    }

    convenience init(event: Event) {
        let item = SentryEnvelopeItem(event: event)
        self.init(header: SentryEnvelopeHeader(id: event.eventId), singleItem: item)
    }
    
    @objc public let header: SentryEnvelopeHeader
    @objc public let items: [SentryEnvelopeItem]

    /// Whether the envelope contains a crash event, so the transport sends it before older cached
    /// envelopes. Only kept in memory; it isn't serialized.
    @objc public let containsCrashEvent: Bool
}
// swiftlint:enable missing_docs
