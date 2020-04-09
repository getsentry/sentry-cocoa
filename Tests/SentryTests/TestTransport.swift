import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var sendAllStoredEventsInvocations: UInt = 0
    var lastSentEvent: Event? = nil
   
    public func send(event: Event, completion completionHandler: SentryRequestFinished? = nil) {
        lastSentEvent = event
    }
    
    public func send(envelope: SentryEnvelope, completion completionHandler: SentryRequestFinished? = nil) {
        
    }
    
    public func sendAllStoredEvents() {
        sendAllStoredEventsInvocations += 1
    }
}
