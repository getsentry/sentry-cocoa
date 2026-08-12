// swiftlint:disable missing_docs
import Foundation

@_spi(Private)
@objc(SentryTransportAdapter)
open class SentryTransportAdapter: NSObject {

    private let transports: [any Transport]
    private let options: Options

    @objc(initWithTransports:options:)
    public init(transports: [any Transport], options: Options) {
        self.transports = transports
        self.options = options
        super.init()
    }

    @objc(sendEvent:session:attachments:)
    public func send(_ event: Event, session: SentrySession, attachments: [Attachment]) {
        send(event, with: session, traceContext: nil, attachments: attachments)
    }

    @objc(sendEvent:traceContext:attachments:)
    open func send(event: Event, traceContext: TraceContext?, attachments: [Attachment]) {
        send(event: event, traceContext: traceContext, attachments: attachments, additionalEnvelopeItems: [])
    }

    @objc(sendEvent:traceContext:attachments:additionalEnvelopeItems:)
    open func send(
        event: Event,
        traceContext: TraceContext?,
        attachments: [Attachment],
        additionalEnvelopeItems: [SentryEnvelopeItem]
    ) {
        var items = buildEnvelopeItems(event, attachments: attachments)
        items.append(contentsOf: additionalEnvelopeItems)

        let envelope = SentryEnvelope(
            header: SentryEnvelopeHeader(id: event.eventId, traceContext: traceContext),
            items: items
        )
        send(envelope: envelope)
    }

    @objc(sendEvent:withSession:traceContext:attachments:)
    open func send(
        _ event: Event,
        with session: SentrySession,
        traceContext: TraceContext?,
        attachments: [Attachment]
    ) {
        var items = buildEnvelopeItems(event, attachments: attachments)
        items.append(SentryEnvelopeItem(session: session))

        let envelope = SentryEnvelope(
            header: SentryEnvelopeHeader(id: event.eventId, traceContext: traceContext),
            items: items
        )
        send(envelope: envelope)
    }

    @objc(storeEvent:traceContext:)
    open func store(_ event: Event, traceContext: TraceContext?) {
        let envelope = SentryEnvelope(
            header: SentryEnvelopeHeader(id: event.eventId, traceContext: traceContext),
            items: [SentryEnvelopeItem(event: event)]
        )
        transports.forEach { $0.store(envelope) }
    }

    @objc(sendEnvelope:)
    public func send(envelope: SentryEnvelope) {
        transports.forEach { $0.send(envelope: envelope) }
    }

    @objc(recordLostEvent:reason:)
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        transports.forEach { $0.recordLostEvent(category, reason: reason) }
    }

    @objc(recordLostEvent:reason:quantity:)
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        transports.forEach { $0.recordLostEvent(category, reason: reason, quantity: quantity) }
    }

    @objc(flush:)
    public func flush(_ timeout: TimeInterval) {
        transports.forEach { _ = $0.flush(timeout) }
    }

    private func buildEnvelopeItems(_ event: Event, attachments: [Attachment]) -> [SentryEnvelopeItem] {
        [SentryEnvelopeItem(event: event)] + attachments.compactMap {
            SentryEnvelopeItem(attachment: $0, maxAttachmentSize: options.maxAttachmentSize)
        }
    }
}
// swiftlint:enable missing_docs
