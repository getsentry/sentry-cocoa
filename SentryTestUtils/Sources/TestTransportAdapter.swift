// swiftlint:disable missing_docs
import _SentryPrivate
import Foundation
@_spi(Private) import Sentry

@_spi(Private) public class TestTransportAdapter: SentryTransportAdapter {
    @_spi(Private)
    public var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceContext: TraceContext?, attachments: [Attachment])>()
    @_spi(Private)
    public override func send(_ event: Event, with session: SentrySession, traceContext: TraceContext?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceContext, attachments))
    }
    
    @_spi(Private) public var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceContext: TraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func send(event: Event, traceContext: TraceContext?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, []))
    }
    
    @_spi(Private) public override func send(event: Event, traceContext: TraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, additionalEnvelopeItems))
    }
    
    public var storeEventInvocations = Invocations<(event: Event, traceContext: TraceContext?)>()
    public override func store(_ event: Event, traceContext: TraceContext?) {
        storeEventInvocations.record((event, traceContext))
    }
}
// swiftlint:enable missing_docs
