#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) import Sentry
#endif
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

    func testInitWithDictionary_whenBeforeSendTransactionIsBlock_shouldSetCallback() throws {
    #if !SDK_V10
        throw XCTSkip("Test is only valid for SDK v10 and above")
    #else
        // -- Arrange --
        let callback: @convention(block) (Transaction, Hint) -> Transaction? = { transaction, _ in transaction }

        // -- Act --
        let options = try Options(dictionary: [
            "dsn": "https://username:password@sentry.io/1",
            "beforeSendTransaction": callback
        ])

        // -- Assert --
        XCTAssertNotNil(options.beforeSendTransaction)
    #endif // SDK_V10
    }

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

    func testInitWithDictionary_whenMetricKitHangReportingModeIsFlamegraphAttachment_shouldSetMode() throws {
        #if canImport(MetricKit) && !os(tvOS)
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metricKitHangReportingMode": "flamegraphAttachment"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.hangReportingMode, .flamegraphAttachment)
        #else
        throw XCTSkip("MetricKit options are not parsed on this platform")
        #endif
    }

    func testInitWithDictionary_whenMetricKitHangReportingModeIsLegacy_shouldSetMode() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metricKitHangReportingMode": "legacy"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.hangReportingMode, .legacy)
    }

    func testInitWithDictionary_whenMetricKitHangReportingModeIsUnknown_shouldKeepDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metricKitHangReportingMode": "unknown"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.hangReportingMode, .legacy)
    }

    func testInitWithDictionary_whenMetricKitHangReportingModeNotSet_shouldDefaultToLegacy() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.hangReportingMode, .legacy)
    }
}
