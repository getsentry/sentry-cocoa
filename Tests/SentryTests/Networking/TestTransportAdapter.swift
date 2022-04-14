import Foundation

public class TestTransportAdapter: SentryTransportAdapter {
    
    public override func send(event: Event, attachments: [Attachment]) {
        self.send(event: event, traceState: nil, attachments: attachments)
    }
    
    public override func send(_ event: Event, session: SentrySession, attachments: [Attachment]) {
        self.send(event, with: session, traceState: nil, attachments: attachments)
    }
    
    var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment])>()
    public override func send(_ event: Event, with session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceState, attachments))
    }
    
    var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceState: SentryTraceState?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func send(event: Event, traceState: SentryTraceState?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceState, attachments, []))
    }
    
    public override func send(event: Event, traceState: SentryTraceState?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceState, attachments, additionalEnvelopeItems))
    }

    var userFeedbackInvocations = Invocations<UserFeedback>()
    public override func send(userFeedback: UserFeedback) {
        userFeedbackInvocations.record(userFeedback)
    }
}
