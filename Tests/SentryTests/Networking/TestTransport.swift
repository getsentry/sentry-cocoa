import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEnvelope: SentryEnvelope?
    var sentEvents: [Event] = []
   
    public func send(event: Event, completion completionHandler: SentryRequestFinished? = nil) {
        sentEvents.append(event)
    }
    
    public func send(envelope: SentryEnvelope, completion completionHandler: SentryRequestFinished? = nil) {
        lastSentEnvelope = envelope
    }
}
