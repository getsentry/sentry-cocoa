import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEnvelope: SentryEnvelope?
    var sentEvents: [Event] = []
   
    public func send(event: Event) {
        sentEvents.append(event)
    }
    
    var sentEventsWithSession: [Pair<Event, SentrySession>] = []
    public func send(_ event: Event, with session: SentrySession) {
        sentEventsWithSession.append(Pair(event, session))
    }
    
    var sentUserFeedback: [UserFeedback] = []
    public func send(userFeedback: UserFeedback) {
        sentUserFeedback.append(userFeedback)
    }
    
    public func send(envelope: SentryEnvelope) {
        lastSentEnvelope = envelope
    }
}
