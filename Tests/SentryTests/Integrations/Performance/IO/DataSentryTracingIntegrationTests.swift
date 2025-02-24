@testable import Sentry
import SentryTestUtils
import XCTest

class DataSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {

        let data = "SOME DATA".data(using: .utf8)!

        var fileUrlToRead: URL!
        var fileUrlToWrite: URL!
        var ignoredFileUrl: URL!

        init() {}

        func getSut(testName: String, isEnabled: Bool = true) throws -> Data {
            SentrySDK.start { options in
                options.dsn = TestConstants.dsnAsString(username: "DataSentryTracingIntegrationTests")
                options.removeAllIntegrations()

                // Configure options required by File I/O tracking integration
                options.enableAutoPerformanceTracing = true
                options.enableFileIOTracing = isEnabled
                options.setIntegrations(isEnabled ? [SentryFileIOTrackingIntegration.self] : [])

                // Configure the tracing sample rate to record all traces
                options.tracesSampleRate = 1.0

                // NOTE: We are not testing for the case where swizzling is enabled, as it could lead to duplicate spans on older OS versions.
                // Instead we are recommending to disable swizzling and use manual tracing.
                options.enableSwizzling = true
                options.experimental.enableDataSwizzling = false
                options.experimental.enableFileManagerSwizzling = false
            }

            // Get the working directory of the SDK, as the path is using the DSN hash to avoid conflicts
            guard let sentryBasePath = SentrySDK.currentHub().getClient()?.fileManager.basePath else {
                preconditionFailure("Sentry base path is nil, but should be configured for test cases.")
            }
            let sentryBasePathUrl = URL(fileURLWithPath: sentryBasePath)

            fileUrlToRead = sentryBasePathUrl.appendingPathComponent("file-to-read")
            try data.write(to: fileUrlToRead)

            fileUrlToWrite = sentryBasePathUrl.appendingPathComponent("file-to-write")

            // Get the working directory of the SDK, as these files are ignored by default
            guard let sentryPath = SentrySDK.currentHub().getClient()?.fileManager.sentryPath else {
                preconditionFailure("Sentry path is nil, but should be configured for test cases.")
            }
            let sentryPathUrl = URL(fileURLWithPath: sentryPath)

            ignoredFileUrl = sentryPathUrl.appendingPathComponent("ignored-file")
            try data.write(to: ignoredFileUrl)

            return data
        }

        var invalidFileUrlToRead: URL {
            URL(fileURLWithPath: "/dev/null")
        }

        var invalidFileUrlToWrite: URL {
            URL(fileURLWithPath: "/path/that/does/not/exist")
        }

        var nonFileUrl: URL {
            // URL to a file that is not a file but should exist at all times
            URL(string: "https://raw.githubusercontent.com/getsentry/sentry-cocoa/refs/heads/main/.gitignore")!
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Data.init(contentsOfUrlWithSentryTracing:)

    func testInitContentsOfUrlWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfUrlWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRead)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
    }

    func testInitContentsOfUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try Data(contentsOfUrlWithSentryTracing: fixture.invalidFileUrlToRead))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRead)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToRead.path)
        XCTAssertNil(span.data["file.size"])
    }

    func testInitContentsOfUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfUrlWithSentryTracing: fixture.nonFileUrl)

        // -- Assert --
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfUrlWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfUrlWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfUrlWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfUrlWithSentryTracing: fixture.ignoredFileUrl)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfUrlWithSentryTracing_SDKIsNotEnabled_shouldReadData() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // -- Act --
        let data = try Data(contentsOfUrlWithSentryTracing: fixture.ignoredFileUrl)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, fixture.data)
    }

    // MARK: - Data.writeWithSentryTracing(to:)

    func testWriteWithSentryTracing_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: .atomic)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // Reading the written data will create a span, so do it after asserting the transaction
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)
    }

    func testWriteWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.writeWithSentryTracing(to: fixture.invalidFileUrlToWrite))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToWrite.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
    }

    func testWriteWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        XCTAssertThrowsError(try sut.writeWithSentryTracing(to: fixture.nonFileUrl, options: .atomic))

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: .atomic)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.ignoredFileUrl, options: .atomic)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.ignoredFileUrl)
        XCTAssertEqual(writtenData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_SDKIsNotStarted_shouldWriteFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.ignoredFileUrl, options: .atomic)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        let writtenData = try Data(contentsOf: fixture.ignoredFileUrl)
        XCTAssertEqual(writtenData, fixture.data)
    }
}
