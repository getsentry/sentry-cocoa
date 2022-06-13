import Foundation

public class TestTransportAdapter: SentryTransportAdapter {
    
    public override func send(event: Event, attachments: [Attachment]) {
        self.send(event: event, traceContext: nil, attachments: attachments)
    }
    
    public override func send(_ event: Event, session: SentrySession, attachments: [Attachment]) {
        self.send(event, with: session, traceContext: nil, attachments: attachments)
    }
    
    var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceContext: SentryTraceContext?, attachments: [Attachment])>()
    public override func send(_ event: Event, with session: SentrySession, traceContext: SentryTraceContext?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceContext, attachments))
    }
    
    var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func send(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, []))
    }
    
    public override func send(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, additionalEnvelopeItems))
    }

    var userFeedbackInvocations = Invocations<UserFeedback>()
    public override func send(userFeedback: UserFeedback) {
        userFeedbackInvocations.record(userFeedback)
    }
}
