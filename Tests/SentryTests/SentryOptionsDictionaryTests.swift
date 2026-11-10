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

    // MARK: - Every option

    func testInitWithDictionary_whenAnyOption_shouldApplyValue() throws {
        let defaults = Options()
        // Skips the options that don't exist in the build under test.
        for (name, entry) in dictionaryOptionValues.sorted(by: { $0.key < $1.key }) where defaults.responds(to: NSSelectorFromString(name)) {
            // -- Arrange --
            let defaultValue = defaults.value(forKey: name)
            let value = entry is OppositeOfDefaultBool ? !(try XCTUnwrap(defaultValue as? Bool, "'\(name)' is not a boolean")) : entry
            // A value equal to the default would pass for an option the initializer ignores.
            XCTAssertFalse(isEqual(defaultValue, value), "The value for '\(name)' must differ from its default")
            var dictionary: [String: Any] = ["dsn": validDsn]
            dictionary[name] = value

            // -- Act --
            let options = try Options(dictionary: dictionary)

            // -- Assert --
            let applied = options.value(forKey: name)
            // A callback can't be compared, only checked for presence.
            let isApplied = value as AnyObject === callback as AnyObject ? applied != nil : isEqual(applied, value)
            XCTAssertTrue(isApplied, "The dictionary initializer ignores '\(name)'")
        }
    }

    func testOptions_whenEveryProperty_shouldHaveDictionaryValueOrBeListedAsUntested() {
        // -- Arrange --
        let accountedFor = Set(dictionaryOptionValues.keys).union(untestedOptions)

        // -- Act --
        let unaccountedFor = extractPropertyNames(from: Options()).subtracting(accountedFor).sorted()

        // -- Assert --
        XCTAssertEqual(unaccountedFor, [], """
            These Options properties are not covered by the dictionary test. For each one, read it in
            Options+Dictionary.swift and add it to dictionaryOptionValues. If it can't be set from a
            dictionary, add it to untestedOptions with the reason in a comment.
            """)
    }

    private func isEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        (lhs as AnyObject).isEqual(rhs)
    }
}

private let validDsn = "https://username:password@sentry.io/1"
private let callback: @convention(block) () -> Void = { }
private final class TestURLSessionDelegate: NSObject, URLSessionDelegate {}

/// Marks a boolean option, for which the test passes the opposite of whatever its default is.
private struct OppositeOfDefaultBool {}
private let oppositeOfDefaultBool = OppositeOfDefaultBool()

/// A value that differs from the default for every option the dictionary initializer reads under
/// the property's name. Names options of every platform and SDK version; the test skips the ones
/// that don't exist in the build under test.
private let dictionaryOptionValues: [String: Any] = [
    "appHangTimeoutInterval": 7.0,
    "attachAllThreads": oppositeOfDefaultBool,
    "attachScreenshot": oppositeOfDefaultBool,
    "attachStacktrace": oppositeOfDefaultBool,
    "attachViewHierarchy": oppositeOfDefaultBool,
    "beforeBreadcrumb": callback,
    "beforeCaptureScreenshot": callback,
    "beforeCaptureViewHierarchy": callback,
    "beforeSend": callback,
    "beforeSendLog": callback,
    "beforeSendSpan": callback,
    "beforeSendTransaction": callback,
    "cacheDirectoryPath": "/fake/cache/directory",
    "debug": oppositeOfDefaultBool,
    "dist": "fake-dist",
    "dsn": validDsn,
    "enableAppHangTracking": oppositeOfDefaultBool,
    "enableAutoBreadcrumbTracking": oppositeOfDefaultBool,
    "enableAutoPerformanceTracing": oppositeOfDefaultBool,
    "enableAutoSessionTracking": oppositeOfDefaultBool,
    "enableCaptureFailedRequests": oppositeOfDefaultBool,
    "enableCoreDataTracing": oppositeOfDefaultBool,
    "enableCrashHandler": oppositeOfDefaultBool,
    "enableDataSwizzling": oppositeOfDefaultBool,
    "enableFileIOTracing": oppositeOfDefaultBool,
    "enableFileManagerSwizzling": oppositeOfDefaultBool,
    "enableGraphQLOperationTracking": oppositeOfDefaultBool,
    "enableLogs": oppositeOfDefaultBool,
    "enableMemoryIntrospection": oppositeOfDefaultBool,
    "enableMetricKit": oppositeOfDefaultBool,
    "enableMetricKitRawPayload": oppositeOfDefaultBool,
    "enableMetrics": oppositeOfDefaultBool,
    "enableNetworkBreadcrumbs": oppositeOfDefaultBool,
    "enableNetworkTracking": oppositeOfDefaultBool,
    "enablePersistingTracesWhenCrashing": oppositeOfDefaultBool,
    "enablePreWarmedAppStartTracing": oppositeOfDefaultBool,
    "enablePropagateTraceparent": oppositeOfDefaultBool,
    "enableReportNonFullyBlockingAppHangs": oppositeOfDefaultBool,
    "enableScopePersistence": oppositeOfDefaultBool,
    "enableSigtermReporting": oppositeOfDefaultBool,
    "enableSpotlight": oppositeOfDefaultBool,
    "enableStandaloneAppStartTracing": oppositeOfDefaultBool,
    "enableSwizzling": oppositeOfDefaultBool,
    "enableTimeToFullDisplayTracing": oppositeOfDefaultBool,
    "enableUIViewControllerTracing": oppositeOfDefaultBool,
    "enableUncaughtNSExceptionReporting": oppositeOfDefaultBool,
    "enableUnhandledCPPExceptionsV2": oppositeOfDefaultBool,
    "enableUserInteractionTracing": oppositeOfDefaultBool,
    "enableWatchdogTerminationTracking": oppositeOfDefaultBool,
    "enabled": oppositeOfDefaultBool,
    "environment": "fake-environment",
    "failedRequestStatusCodes": [HttpStatusCodeRange(min: 400, max: 499)],
    "failedRequestTargets": ["fake-failed-request-target"],
    "idleTimeout": 7.0,
    "maxAttachmentSize": 7,
    "maxBreadcrumbs": 7,
    "maxCacheItems": 7,
    "maxFeatureFlags": 7,
    "onCrashedLastRun": callback,
    "onLastRunStatusDetermined": callback,
    "orgId": "fake-org-id",
    "reportAccessibilityIdentifier": oppositeOfDefaultBool,
    "sampleRate": 0.25,
    "sendClientReports": oppositeOfDefaultBool,
    "sendDefaultPii": oppositeOfDefaultBool,
    "sessionTrackingIntervalMillis": 7,
    "shutdownTimeInterval": 7.0,
    "spotlightUrl": "http://fake-spotlight-url",
    "strictTraceContinuation": oppositeOfDefaultBool,
    "swiftAsyncStacktraces": oppositeOfDefaultBool,
    "swizzleClassNameExcludes": Set<AnyHashable>(["FakeClass"]),
    "tracePropagationTargets": ["fake-trace-propagation-target"],
    "tracesSampleRate": 0.25,
    "tracesSampler": callback,
    "urlSession": URLSession(configuration: .ephemeral),
    "urlSessionDelegate": TestURLSessionDelegate()
]

/// Properties the test above doesn't include, each with the reason in a comment.
private let untestedOptions: Set<String> = [
    "beforeBreadcrumbWithHint", // Not read from dictionaries; deprecated transitional callback
    "beforeSendMetric", // Not read from dictionaries; Swift-only, so it can't be set by key
    "beforeSendWithHint", // Not read from dictionaries; deprecated transitional callback
    "configureProfiling", // Not read from dictionaries; hybrid SDKs set it after init
    "configureUserFeedback", // Not read from dictionaries
    "dataCollection", // Nested dictionary, covered by SentryOptionsTests
    "dataCollectionObjC", // Objective-C bridge of dataCollection
    "diagnosticLevel", // Read from the level's name, covered by SentryOptionsTest
    "effectiveOrgId", // Computed from orgId and dsn
    "enableReportNonFullyBlockingAppHangsValue", // Backing storage of enableReportNonFullyBlockingAppHangs
    "experimental", // Only its MetricKit keys, covered above, and enableUnhandledCPPExceptionsV2 are read from dictionaries
    "inAppIncludes", // The dictionary value is appended to the defaults instead of replacing them, covered by SentryOptionsTest
    "initialScope", // Has a default callback, which can't be told apart from one set by a dictionary, covered by SentryOptionsTest
    "isTracingEnabled", // Computed from tracesSampleRate and tracesSampler
    "parsedDsn", // Derived from dsn
    "privacy", // Nested dictionary, covered by SentryPrivacyOptionsTests
    "profiling", // Set by configureProfiling
    "releaseName", // Read from the release key, covered by testInitWithDictionary_whenValidValues_shouldPopulateOptions
    "screenshot", // Not read from dictionaries; hybrid SDKs set it after init
    "sessionReplay", // Nested dictionary, covered by SentryOptionsTest
    "userFeedbackConfiguration" // Set by configureUserFeedback
]
