import XCTest

struct TestConstants {
    
    static func dsnAsString(username: String) -> String {
        return "https://\(username):password@app.getsentry.com/12345"
    }
    
    static func dsn(username: String) -> SentryDsn {
        var dsn: SentryDsn?
        do {
            dsn = try SentryDsn(string: self.dsnAsString(username: username))
        } catch {
            XCTFail("SentryDsn could not be created")
        }

        // The test fails if the dsn could not be created
        return dsn!
    }
    
    static var eventWithSerializationError: Event {
        let event = Event()
        event.message = SentryMessage(formatted: "")
        event.sdk = ["event": Event()]
        return event
    }
    
    static var envelope: SentryEnvelope {
        let event = Event()
        let envelopeItem = SentryEnvelopeItem(event: event)
        return SentryEnvelope(id: event.eventId, singleItem: envelopeItem)
    }
}
