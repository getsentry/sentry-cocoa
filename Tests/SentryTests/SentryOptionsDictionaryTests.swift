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
            "includeLocalVariables": false
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
        XCTAssertFalse(options.includeLocalVariables)
    }

    func testInitWithDictionary_whenBeforeSendTransactionIsBlock_shouldSetCallback() throws {
    #if !SDK_V10
        throw XCTSkip("Test is only valid for SDK v10 and above")
    #else
        // -- Arrange --
        let callback: @convention(block) (Event) -> Event? = { $0 }

        // -- Act --
        let options = try Options(dictionary: [
            "dsn": "https://username:password@sentry.io/1",
            "beforeSendTransaction": callback
        ])

        // -- Assert --
        XCTAssertNotNil(options.beforeSendTransaction)
    #endif // SDK_V10
    }

    func testInitWithDictionary_whenIncludeLocalVariablesNotSet_shouldDefaultToTrue() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertTrue(options.includeLocalVariables)
    }

    func testInitWithDictionary_whenLegacyMemoryIntrospectionSet_shouldPopulateLocalVariables() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "enableMemoryIntrospection": false
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.includeLocalVariables)
    }

    func testInitWithDictionary_whenBothLocalVariableKeysSet_shouldPreferNewKey() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "includeLocalVariables": true,
            "enableMemoryIntrospection": false
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertTrue(options.includeLocalVariables)
    }
}
