@_implementationOnly import _SentryPrivate

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
    
    @objc(initWithHeader:items:) public init(header: SentryEnvelopeHeader, items: [SentryEnvelopeItem]) {
        self.header = header
        self.items = items
    }

    convenience init(event: Event) {
        let item = SentryEnvelopeItem(event: event)
        self.init(header: SentryEnvelopeHeader(id: event.eventId), singleItem: item)
    }
    
    @objc public let header: SentryEnvelopeHeader
    @objc public let items: [SentryEnvelopeItem]
}
