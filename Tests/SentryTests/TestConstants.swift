import XCTest

struct TestConstants {
    static let dsnAsString: String = "https://username:password@app.getsentry.com/12345"

    static var dsn: SentryDsn {
        var dsn: SentryDsn?
        do {
            dsn = try SentryDsn(string: self.dsnAsString)
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
