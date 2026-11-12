#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#else
@_spi(Private) import Sentry
#endif
import XCTest

final class SentryOptionsDictionaryTests: XCTestCase {
    func testInitWithDictionary_whenUserPersistenceConfigured_shouldUseBooleanValue() throws {
        // -- Arrange --
        let base: [String: Any] = ["dsn": "https://username:password@sentry.io/1"]

        // -- Act --
        let defaults = try Options(dictionary: base)
        let enabled = try Options(dictionary: base.merging(["enableScopePersistence": true]) { _, value in value })
        let disabled = try Options(dictionary: base.merging(["enableScopePersistence": false]) { _, value in value })

        // -- Assert --
        #if SDK_V10
        XCTAssertTrue(defaults.enableScopePersistence)
        #else
        XCTAssertFalse(defaults.enableScopePersistence)
        #endif
        XCTAssertTrue(enabled.enableScopePersistence)
        XCTAssertFalse(disabled.enableScopePersistence)
    }

    func testInitWithDictionary_whenAttachAllThreadsConfigured_shouldUseBooleanValue() throws {
        // -- Arrange --
        let base: [String: Any] = ["dsn": "https://username:password@sentry.io/1"]

        // -- Act --
        let defaults = try Options(dictionary: base)
        let enabled = try Options(dictionary: base.merging(["attachAllThreads": true]) { _, value in value })
        let disabled = try Options(dictionary: base.merging(["attachAllThreads": false]) { _, value in value })

        // -- Assert --
        XCTAssertFalse(defaults.attachAllThreads)
        XCTAssertTrue(enabled.attachAllThreads)
        XCTAssertFalse(disabled.attachAllThreads)
    }

    func testInitWithDictionary_whenDataSwizzlingConfigured_shouldUseBooleanValue() throws {
        // -- Arrange --
        let base: [String: Any] = ["dsn": "https://username:password@sentry.io/1"]

        // -- Act --
        let defaults = try Options(dictionary: base)
        let enabled = try Options(dictionary: base.merging(["enableDataSwizzling": true]) { _, value in value })
        let disabled = try Options(dictionary: base.merging(["enableDataSwizzling": false]) { _, value in value })

        // -- Assert --
        XCTAssertTrue(defaults.enableDataSwizzling)
        XCTAssertTrue(enabled.enableDataSwizzling)
        XCTAssertFalse(disabled.enableDataSwizzling)
    }

    func testInitWithDictionary_whenStandaloneAppStartTracingConfigured_shouldUseBooleanValue() throws {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK && !SDK_V10
        // -- Arrange --
        let base: [String: Any] = ["dsn": "https://username:password@sentry.io/1"]

        // -- Act --
        let defaults = try Options(dictionary: base)
        let enabled = try Options(dictionary: base.merging(["enableStandaloneAppStartTracing": true]) { _, value in value })
        let disabled = try Options(dictionary: base.merging(["enableStandaloneAppStartTracing": false]) { _, value in value })

        // -- Assert --
        XCTAssertFalse(defaults.enableStandaloneAppStartTracing)
        XCTAssertTrue(enabled.enableStandaloneAppStartTracing)
        XCTAssertFalse(disabled.enableStandaloneAppStartTracing)
        #else
        throw XCTSkip("Standalone app start tracing is not available on this platform or SDK version")
        #endif
    }

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
