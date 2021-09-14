import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEnvelope: SentryEnvelope?
    
    public func send(event: Event, attachments: [Attachment]) {
        self.send(event: event, traceState: nil, attachments: attachments)
    }
    
    public func send(_ event: Event, with session: SentrySession, attachments: [Attachment]) {
        self.send(event, with: session, traceState: nil, attachments: attachments)
    }
    
    var sentEventsWithSessionTraceState: [(event: Event, session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment])] = []
    public func send(_ event: Event, with session: SentrySession, traceState: SentryTraceState?, attachments: [Attachment]) {
        sentEventsWithSessionTraceState.append((event, session, traceState, attachments))
    }
    
    var sentEventsTraceState: [(event: Event, traceState: SentryTraceState?, attachments: [Attachment])] = []
    public func send(event: Event, traceState: SentryTraceState?, attachments: [Attachment]) {
        sentEventsTraceState.append((event, traceState, attachments))
    }
          
    var sentUserFeedback: [UserFeedback] = []
    public func send(userFeedback: UserFeedback) {
        sentUserFeedback.append(userFeedback)
    }
    
    public func send(envelope: SentryEnvelope) {
        lastSentEnvelope = envelope
    }
}
