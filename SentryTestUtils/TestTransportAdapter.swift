import _SentryPrivate
import Foundation

public class TestTransportAdapter: SentryTransportAdapter {
    public var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceContext: TraceContext?, attachments: [Attachment])>()
    public override func send(_ event: Event, with session: SentrySession, traceContext: TraceContext?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceContext, attachments))
    }
    
    public var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceContext: TraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func send(event: Event, traceContext: TraceContext?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, []))
    }
    
    public override func send(event: Event, traceContext: TraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, additionalEnvelopeItems))
    }
    
    public var storeEventInvocations = Invocations<(event: Event, traceContext: TraceContext?)>()
    public override func store(_ event: Event, traceContext: TraceContext?) {
        storeEventInvocations.record((event, traceContext))
    }

    public var userFeedbackInvocations = Invocations<UserFeedback>()
    public override func send(userFeedback: UserFeedback) {
        userFeedbackInvocations.record(userFeedback)
    }
}
