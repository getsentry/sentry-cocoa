@testable import Sentry
import SentryTestMock
import SentryTestUtils
import XCTest

/// Tests related to the Sentry-specific methods extending the type ``Swift.Data``.
///
/// These tests are unit tests and are responsible for testing the logic in isolation from the remaining SDK.
/// As the extensions rely on the ``SentryFileIOTracker``, they are tested in combination.
class DataSentryTracingTests: XCTestCase {
    private var fileIOTracker: SentryFileIOTracker!

    private let mockedSentryThreadInspector = MockSentryThreadInspector()
    private let mockedSentryProcessInfoWrapper = MockSentryNSProcessInfoWrapper()
    private let mockedSentryScope = MockSentryScope()
    private let mockedSentryClient = MockSentryClient(options: Options())
    private var mockedSentryHub: MockSentryHub!

    private let testData = "SOME DATA".data(using: .utf8)!

    private var fileUrlToRead: URL!
    private var fileUrlToWrite: URL!
    private var ignoredFileUrl: URL!
    private let invalidFileUrlToRead = URL(fileURLWithPath: "/dev/null")
    private let invalidFileUrlToWrite = URL(fileURLWithPath: "/path/that/does/not/exist")
    // URL to a file that is not a file but should exist at all times
    private let nonFileUrl = URL(string: "https://raw.githubusercontent.com/getsentry/sentry-cocoa/refs/heads/main/.gitignore")!

    override func setUpWithError() throws {
        try super.setUpWithError()

        mockedSentryHub = MockSentryHub(client: mockedSentryClient, andScope: mockedSentryScope)
        SentrySDK.setCurrentHub(mockedSentryHub)

        fileIOTracker = SentryFileIOTracker(threadInspector: mockedSentryThreadInspector, processInfoWrapper: mockedSentryProcessInfoWrapper)
        SentryDependencyContainer.sharedInstance().fileIOTracker = fileIOTracker

        // Create a working directory unique to the currently executed test
        let basePathUrl = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-\(self.name.hashValue.description)")
        try! FileManager.default
            .createDirectory(at: basePathUrl, withIntermediateDirectories: true)

        fileUrlToRead = basePathUrl.appendingPathComponent("file-to-read")
        try testData.write(to: fileUrlToRead)

        fileUrlToWrite = basePathUrl.appendingPathComponent("file-to-write")
    }

    override func tearDown() {
        super.tearDown()

        mockedSentryThreadInspector.clearAllMocks()
        mockedSentryProcessInfoWrapper.clearAllMocks()
        mockedSentryScope.clearAllMocks()
        mockedSentryClient?.clearAllMocks()
        mockedSentryHub?.clearAllMocks()
    }

    // MARK: - Data.init(contentsOfWithSentryTracing:)

    func testInitContentsOfWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let expectedStartTimestamp = Date(timeIntervalSince1970: 4_000_000)
        let expectedEndTimestamp = Date(timeIntervalSince1970: 4_005_000)

        let ioSpan = MockSentrySpan()
        ioSpan.startTimestamp = expectedStartTimestamp
        ioSpan.timestamp = expectedEndTimestamp

        let mockParentSpan = MockSentrySpan()
        mockParentSpan.mockStartChildWithOperationDescription.returnValue(ioSpan)
        mockedSentryScope.span = mockParentSpan

        fileIOTracker.enable()

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, testData)

        XCTAssertEqual(ioSpan.status, SentrySpanStatus.ok)
        XCTAssertEqual(ioSpan.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(ioSpan.data[SentrySpanDataKey.filePath] as? String, fileUrlToRead.path)
        XCTAssertEqual(ioSpan.data[SentrySpanDataKey.fileSize] as? Int, testData.count)

        XCTAssertEqual(ioSpan.startTimestamp, expectedStartTimestamp)
        XCTAssertEqual(ioSpan.timestamp, expectedEndTimestamp)

        sentryExpect(mockParentSpan.mockStartChildWithOperationDescription)
            .toHaveBeenCalledWith(
                SentrySpanOperation.fileRead,
                "file-to-read"
            )
    }
}
