import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEnvelope: SentryEnvelope?
    
    var sentEvents: [(event: Event, attachments: [Attachment])] = []
    public func send(event: Event, attachments: [Attachment]) {
        sentEvents.append((event, attachments))
    }
    
    var sentEventsWithSession: [(event: Event, session: SentrySession, attachments: [Attachment])] = []
    public func send(_ event: Event, with session: SentrySession, attachments: [Attachment]) {
        sentEventsWithSession.append((event, session, attachments))
    }
    
    var sentUserFeedback: [UserFeedback] = []
    public func send(userFeedback: UserFeedback) {
        sentUserFeedback.append(userFeedback)
    }
    
    public func send(envelope: SentryEnvelope) {
        lastSentEnvelope = envelope
    }
}
