import Foundation

@objc
public class TestTransport: NSObject, Transport {
    
    var lastSentEvent: Event?
   
    public func send(event: Event, completion completionHandler: SentryRequestFinished? = nil) {
        lastSentEvent = event
    }
    
    public func send(envelope: SentryEnvelope, completion completionHandler: SentryRequestFinished? = nil) {
    }
}
