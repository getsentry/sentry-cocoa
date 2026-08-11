@_spi(Private) import Sentry
import XCTest

final class SentryOptionsDictionaryTests: XCTestCase {
    func testInitWithDictionary_whenValidValues_shouldPopulateOptions() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "debug": true,
            "environment": "staging",
            "release": "1.2.3",
            "sampleRate": 0.25,
            "enableMemoryIntrospection": true
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dsn, "https://username:password@sentry.io/1")
        XCTAssertNotNil(options.parsedDsn)
        XCTAssertTrue(options.debug)
        XCTAssertEqual(options.environment, "staging")
        XCTAssertEqual(options.releaseName, "1.2.3")
        XCTAssertEqual(options.sampleRate?.doubleValue, 0.25)
        XCTAssertTrue(options.enableMemoryIntrospection)
    }

    #if SDK_V10
    func testInitWithDictionary_whenBeforeSendTransactionIsBlock_shouldSetCallback() throws {
        // -- Arrange --
        let callback: @convention(block) (Event) -> Event? = { $0 }

        // -- Act --
        let options = try Options(dictionary: [
            "dsn": "https://username:password@sentry.io/1",
            "beforeSendTransaction": callback
        ])

        // -- Assert --
        XCTAssertNotNil(options.beforeSendTransaction)
    }
    #endif // SDK_V10

    func testInitWithDictionary_whenMemoryIntrospectionNotSet_shouldDefaultToFalse() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.enableMemoryIntrospection)
    }
}
