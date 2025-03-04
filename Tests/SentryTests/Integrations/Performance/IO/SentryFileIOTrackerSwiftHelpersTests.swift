@testable import Sentry
import SentryTestUtils
import XCTest

class SentryFileIOTrackerSwiftHelpersTests: XCTestCase {
    private var hub: SentryHub!
    private var tracker: SentryFileIOTracker!
    private var mockedDateProvider: TestCurrentDateProvider!

    private let testData = Data([0x00, 0x01, 0x02, 0x03])
    private let testUrl = URL(fileURLWithPath: "/path/to/file")
    private let testOptions: Data.ReadingOptions = [.alwaysMapped]
    private let testOrigin = "custom.origin"

    override func setUp() {
        mockedDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = mockedDateProvider

        hub = SentryHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)

        tracker = SentryFileIOTracker(
            threadInspector: TestThreadInspector(options: .noIntegrations()),
            processInfoWrapper: TestSentryNSProcessInfoWrapper()
        )
    }

    // MARK: - SentryFileIOTracker.measureReadingData(from:options:origin:)

    func testMeasureReadingData_shouldCreateSpanWithOrderedTimestamps() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_000_000))
        let transaction = hub.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        // Advance the time to make sure the child span has a different start time than the parent span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_100_000))
        let _ = tracker.measureReadingData(from: testUrl, options: testOptions, origin: testOrigin) { _, _ in
            // Advance the time to make sure the child span has a different start and end time
            mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_200_000))
            return testData
        }

        // Advance the time to make sure the parent span has a different end time than the child span
        mockedDateProvider.setDate(date: Date(timeIntervalSince1970: 4_300_000))
        transaction.finish()

        // -- Assert --
        let parentSpan = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(parentSpan.children.count, 1)
        let span = try XCTUnwrap(parentSpan.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, testOrigin)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        XCTAssertEqual(span.data["file.path"] as? String, testUrl.path)
        XCTAssertEqual(span.data["file.size"] as? Int, testData.count)

        XCTAssertEqual(parentSpan.startTimestamp, Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(span.startTimestamp, Date(timeIntervalSince1970: 4_100_000))
        XCTAssertEqual(span.timestamp, Date(timeIntervalSince1970: 4_200_000))
        XCTAssertEqual(parentSpan.timestamp, Date(timeIntervalSince1970: 4_300_000))
    }

    func testMeasureReadingData_isEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.enable()

        // -- Act --
        var callUrl: URL?
        var callOptions: Data.ReadingOptions?
        let result = tracker.measureReadingData(from: testUrl, options: testOptions, origin: testOrigin) { url, options in
            callUrl = url
            callOptions = options
            return testData
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testOptions)
        XCTAssertEqual(result, testData)
    }

    func testMeasureReadingData_isNotEnabled_shouldCallBlockWithParams() throws {
        // -- Arrange --
        tracker.disable()

        // -- Act --
        var callUrl: URL?
        var callOptions: Data.ReadingOptions?
        let result = tracker.measureReadingData(from: testUrl, options: testOptions, origin: testOrigin) { url, options in
            callUrl = url
            callOptions = options
            return testData
        }

        // -- Assert --
        XCTAssertEqual(callUrl, testUrl)
        XCTAssertEqual(callOptions, testOptions)
        XCTAssertEqual(result, testData)
    }
}
