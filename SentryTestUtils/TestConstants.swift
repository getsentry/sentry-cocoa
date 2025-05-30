public struct TestConstants {
    
    /**
     * Real dsn for integration tests.
     */
    public static let realDSN: String = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"

    /**
     * Derives a unique DSN for the test case based on the type and optional test name.
     *
     * This is useful for generating a unique folder hierarchy isolated per test.
     */
    public static func dsnForTestCase<T>(type: T.Type, testName: String? = nil) -> String {
        return "https://\(String(describing: type)):\(testName ?? "unknown")@app.getsentry.com/12345"
    }

    public static func dsnAsString(username: String) -> String {
        return "https://\(username):password@app.getsentry.com/12345"
    }
    
    public static func dsn(username: String) throws -> SentryDsn {
        return try SentryDsn(string: self.dsnAsString(username: username))
    }
    
    public static var eventWithSerializationError: Event {
        let event = Event()
        event.message = SentryMessage(formatted: "")
        event.sdk = ["event": Event()]
        return event
    }
    
    public static var envelope: SentryEnvelope {
        let event = Event()
        let envelopeItem = SentryEnvelopeItem(event: event)
        return SentryEnvelope(id: event.eventId, singleItem: envelopeItem)
    }
}
