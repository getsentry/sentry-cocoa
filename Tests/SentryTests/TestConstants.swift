import XCTest

struct TestConstants {
    static let dsnAsString: NSString = "https://username:password@app.getsentry.com/12345"

    static var dsn: SentryDsn {
        var dsn: SentryDsn?
        do {
            dsn = try SentryDsn(string: self.dsnAsString as String)
        } catch {
            XCTFail("SentryDsn could not be created")
        }

        // The test fails if the dsn could not be created
        // swiftlint:disable force_unwrapping
        return dsn!
        // swiftlint:enable force_unwrapping
    }
    
    static var eventWithSerializationError: Event {
        let event = Event()
        event.message = ""
        event.sdk = ["event": Event()]
        return event
    }
    
    static var envelope: SentryEnvelope {
        let event = Event()
        let envelopeItem = SentryEnvelopeItem(event: event)
        return SentryEnvelope(id: event.eventId, singleItem: envelopeItem)
    }
}
