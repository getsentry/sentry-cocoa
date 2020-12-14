import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEnvelope: SentryEnvelope?
    
    var sentEvents: [Pair<Event, [Attachment]>] = []
    public func send(event: Event, attachments: [Attachment]) {
        sentEvents.append(Pair(event, attachments))
    }
    
    var sentEventsWithSession: [Triple<Event, SentrySession, [Attachment]>] = []
    public func send(_ event: Event, with session: SentrySession, attachments: [Attachment]) {
        sentEventsWithSession.append(Triple(event, session, attachments))
    }
    
    var sentUserFeedback: [UserFeedback] = []
    public func send(userFeedback: UserFeedback) {
        sentUserFeedback.append(userFeedback)
    }
    
    public func send(envelope: SentryEnvelope) {
        lastSentEnvelope = envelope
    }
}
