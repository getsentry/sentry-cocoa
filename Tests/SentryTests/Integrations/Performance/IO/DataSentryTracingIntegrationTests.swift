@testable import Sentry
import SentryTestUtils
import XCTest

class DataSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {

        let data = "SOME DATA".data(using: .utf8)!

        var fileUrlToRead: URL!
        var fileUrlToWrite: URL!

        init() {}

        func getSut(testName: String) throws {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try! FileManager.default
                .createDirectory(at: tempDir, withIntermediateDirectories: true)

            fileUrlToRead = tempDir.appendingPathComponent("file-to-read")
            try data.write(to: fileUrlToRead)

            fileUrlToWrite = tempDir.appendingPathComponent("file-to-write")

            // Initialize the SDK after files are written, so preparations are not traced
            SentrySDK.start { options in
                options.enableSwizzling = true
                options.enableAutoPerformanceTracing = true
                options.enableFileIOTracing = true
                options.tracesSampleRate = 1.0
                options.setIntegrations([SentryFileIOTrackingIntegration.self])
            }
        }

        var invalidFileUrlToRead: URL {
            URL(fileURLWithPath: "/dev/null")
        }

        var invalidFileUrlToWrite: URL {
            URL(fileURLWithPath: "/path/that/does/not/exist")
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
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
        XCTAssertEqual(span.origin, SentryTraceOrigin.autoNSData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRead)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
    }

    func testInitContentsOfUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try Data(contentsOfUrlWithSentryTracing: fixture.invalidFileUrlToRead))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.autoNSData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRead)
        XCTAssertEqual(span.data["file.size"] as? Int, 0)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToRead.path)
    }

    // MARK: - Data.writeWithSentryTracing(to:)

    func testWriteWithSentryTracing_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        try fixture.data.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: .atomic)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.autoNSData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)

        // Reading the written data will create a span, so do it after asserting the transaction
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)
    }

    func testWriteWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.data.writeWithSentryTracing(to: fixture.invalidFileUrlToWrite))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.autoNSData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToWrite.path)
    }
}
