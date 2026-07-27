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
            "enableMemoryIntrospection": false
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
        XCTAssertFalse(options.enableMemoryIntrospection)
    }
}
