import _SentryPrivate
import Foundation

public class TestTransportAdapter: SentryTransportAdapter {
    public override func send(_ event: Event, session: SentrySession, attachments: [Attachment]) {
        self.send(event, with: session, traceContext: nil, attachments: attachments)
    }
    
    public var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceContext: SentryTraceContext?, attachments: [Attachment])>()
    public override func send(_ event: Event, with session: SentrySession, traceContext: SentryTraceContext?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceContext, attachments))
    }
    
    public var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func send(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, []))
    }
    
    public override func send(event: Event, traceContext: SentryTraceContext?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceContext, attachments, additionalEnvelopeItems))
    }

    public var userFeedbackInvocations = Invocations<UserFeedback>()
    public override func send(userFeedback: UserFeedback) {
        userFeedbackInvocations.record(userFeedback)
    }
}
