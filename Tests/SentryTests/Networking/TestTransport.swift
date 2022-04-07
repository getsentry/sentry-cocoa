import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    public func send(event: Event, attachments: [Attachment]) {
        self.send(event: event, traceState: nil, attachments: attachments)
    }
    
    public func send(_ event: Event, with session: SentrySession, attachments: [Attachment]) {
        self.send(event, with: session, traceState: nil, attachments: attachments)
    }
    
    var sentEventsWithSessionTraceState = Invocations<(event: Event, session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment])>()
    public func send(_ event: Event, with session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.record((event, session, traceState, attachments))
    }
    
    var sendEventWithTraceStateInvocations = Invocations<(event: Event, traceState: SentryTraceState?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public func send(event: Event, traceState: SentryTraceState?, attachments: [Attachment]) {
        sendEventWithTraceStateInvocations.record((event, traceState, attachments, []))
    }
    
    public func send(event: Event, traceState: SentryTraceState?, attachments: [Attachment], additionalEnvelopeItems: [SentryEnvelopeItem]) {
        sendEventWithTraceStateInvocations.record((event, traceState, attachments, additionalEnvelopeItems))
    }

    var userFeedbackInvocations = Invocations<UserFeedback>()
    public func send(userFeedback: UserFeedback) {
        userFeedbackInvocations.record(userFeedback)
    }
    
    var lastSentEnvelope = Invocations<SentryEnvelope>()
    public func send(envelope: SentryEnvelope) {
        lastSentEnvelope.record(envelope)
    }
    
    var recordLostEvents = Invocations<(category: SentryDataCategory, reason: SentryDiscardReason)>()
    public func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        recordLostEvents.record((category, reason))
    }
}
