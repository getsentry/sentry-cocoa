#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryOptionsTests: XCTestCase {

    func testSendDefaultPii_whenBuildingV10_shouldNotBeExposed() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
#else
        // -- Arrange --
        let options = Options()

        // -- Assert --
        XCTAssertFalse(options.responds(to: NSSelectorFromString("sendDefaultPii")))
#endif
    }

    func testEnableNewURLLoaderSwizzling_whenDefault_shouldBeFalse() {
        // -- Arrange --
        let options = Options()

        // -- Assert --
        XCTAssertFalse(options.experimental.enableNewURLLoaderSwizzling)
    }

#if canImport(MetricKit) && !os(tvOS)
    func testMetricKitEnabledDiagnosticReports_whenDefault_shouldDependOnSDKVersion() {
        // -- Arrange --
        let options = Options()

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, [.cpuException, .diskWriteException, .hang, .appLaunch])
#else
        XCTAssertTrue(options.experimental.metrickit.enabledDiagnosticReports.isEmpty)
#endif
    }

    func testInitWithDictionary_whenMetricKitIsAbsent_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, SentryMetricKitOptions().enabledDiagnosticReports)
    }

    func testInitWithDictionary_whenMetricKitIsEmpty_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metrickit": [:]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, SentryMetricKitOptions().enabledDiagnosticReports)
    }

    func testInitWithDictionary_whenDiagnosticReportsConfigured_shouldSetEnabledDiagnosticReports() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metrickit": [
                "enabledDiagnosticReports": ["crash", "hang", "cpuException", "diskWriteException", "appLaunch"]
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, [.crash, .hang, .cpuException, .diskWriteException, .appLaunch])
    }

    func testInitWithDictionary_whenDiagnosticReportsEmpty_shouldDisableAllDiagnosticReports() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metrickit": [
                "enabledDiagnosticReports": []
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertTrue(options.experimental.metrickit.enabledDiagnosticReports.isEmpty)
    }

    func testInitWithDictionary_whenDiagnosticReportsContainUnknownValues_shouldIgnoreThem() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metrickit": [
                "enabledDiagnosticReports": ["hang", "unknown", 1, NSNull()]
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, [.hang])
    }

    func testInitWithDictionary_whenDiagnosticReportsIsNotAnArray_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "metrickit": [
                "enabledDiagnosticReports": "hang"
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, SentryMetricKitOptions().enabledDiagnosticReports)
    }

    func testMetricKitEnabledMetricReports_whenDefault_shouldBeEmpty() {
        // -- Arrange --
        let options = Options()

        // -- Assert --
        XCTAssertTrue(options.experimental.metrickit.enabledMetricReports.isEmpty)
    }

    func testMetricKitEnabledMetricReports_whenSetToAll_shouldContainEveryReport() {
        // -- Arrange --
        let options = Options()

        // -- Act --
        options.experimental.metrickit.enabledMetricReports = .all

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledMetricReports, Set(SentryMetricKit.MetricReport.allCases))
    }

    func testMetricKitMetricReportNames_shouldBeUniqueAndNamespaced() {
        // -- Arrange --
        let names = SentryMetricKit.MetricReport.allCases.map(\.name)

        // -- Assert --
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(names.allSatisfy { $0.hasPrefix("metrickit.") }, "Unexpected names: \(names)")
    }
#endif // canImport(MetricKit) && !os(tvOS)

    // MARK: - Data Collection

    func testDataCollection_whenInitialized_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = Options()

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testDataCollection_whenSet_shouldRetainValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let options = Options()

        // -- Act --
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
        #endif
    }

    // MARK: - Data Collection Dictionary Decoding

    func testInitWithDictionary_whenDataCollectionIsAbsent_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsEmpty_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": [:]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": "off"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": NSNull()
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsPresent_shouldSetDataCollection() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": [
                "userInfo": false,
                "graphql": ["variables": false],
                "database": ["queryParams": false],
                "frameContextLines": 0
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options(userInfo: false))
        #endif
    }
}
