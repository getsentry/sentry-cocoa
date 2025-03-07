@testable import Sentry
import SentryTestUtils
import XCTest

class DataSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {
        let mockDateProvider: TestCurrentDateProvider = {
            let provider = TestCurrentDateProvider()
            provider.driftTimeForEveryRead = true
            provider.driftTimeInterval = 0.25
            return provider
        }()

        let data = "SOME DATA".data(using: .utf8)!
        
        var fileUrlToRead: URL!
        var fileUrlToWrite: URL!
        var ignoredFileUrlToRead: URL!
        var ignoredFileUrlToWrite: URL!

        init() {}

        func getSut(testName: String, isSDKEnabled: Bool = true, isEnabled: Bool = true) throws -> Data {
            let fileManager = FileManager.default
            let tempDirUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try! fileManager
                .createDirectory(at: tempDirUrl, withIntermediateDirectories: true)

            if isSDKEnabled {
                SentryDependencyContainer.sharedInstance().dateProvider = mockDateProvider

                SentrySDK.start { options in
                    options.dsn = TestConstants.dsnAsString(username: testName)
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

                // The base path is not unique for the DSN, therefore we need to make it unique
                fileUrlToRead = tempDirUrl.appendingPathComponent("test-\(testName.hashValue.description)--file-to-read")
                try data.write(to: fileUrlToRead)

                fileUrlToWrite = tempDirUrl.appendingPathComponent("test-\(testName.hashValue.description)--file-to-write")
                if fileManager.fileExists(atPath: fileUrlToWrite.path) {
                    try fileManager.removeItem(at: fileUrlToWrite)
                }

                // Get the working directory of the SDK, as these files are ignored by default
                guard let sentryPath = SentrySDK.currentHub().getClient()?.fileManager.sentryPath else {
                    preconditionFailure("Sentry path is nil, but should be configured for test cases.")
                }
                let sentryPathUrl = URL(fileURLWithPath: sentryPath)

                ignoredFileUrlToRead = sentryPathUrl.appendingPathComponent("test--ignored-file-to-read")
                try data.write(to: ignoredFileUrlToRead)

                ignoredFileUrlToWrite = sentryPathUrl.appendingPathComponent("test--ignored-file-to-write")
                if fileManager.fileExists(atPath: ignoredFileUrlToWrite.path) {
                    try fileManager.removeItem(at: ignoredFileUrlToWrite)
                }
            } else {
                fileUrlToRead = tempDirUrl.appendingPathComponent("file-to-read")
                try data.write(to: fileUrlToRead)

                fileUrlToWrite = tempDirUrl.appendingPathComponent("file-to-write")
                if fileManager.fileExists(atPath: fileUrlToWrite.path) {
                    try fileManager.removeItem(at: fileUrlToWrite)
                }
            }
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

        func tearDown() throws {
            clearTestState()

            // Delete files created by the test run
            let manager = FileManager.default
            if fileUrlToRead != nil && manager.fileExists(atPath: fileUrlToRead.path) {
                try manager.removeItem(at: fileUrlToRead)
            }
            if fileUrlToWrite != nil && manager.fileExists(atPath: fileUrlToWrite.path) {
                try manager.removeItem(at: fileUrlToWrite)
            }
            if ignoredFileUrlToRead != nil && manager.fileExists(atPath: ignoredFileUrlToRead.path) {
                try manager.removeItem(at: ignoredFileUrlToRead)
            }
            if ignoredFileUrlToWrite != nil && manager.fileExists(atPath: ignoredFileUrlToWrite.path) {
                try manager.removeItem(at: ignoredFileUrlToWrite)
            }
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDownWithError() throws {
        super.tearDown()
        try fixture.tearDown()
    }

    // MARK: - Data.init(contentsOfWithSentryTracing:)

    func testInitContentsOfWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let data = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, expectedData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testInitContentsOfWithSentryTracingWithOptions_shouldPassOptionsToSystemImplementation() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)

        // To verify that the option is passed, we are using the `alwaysMapped` option.
        // We expect the option to read the data differently when set.
        //
        // Due to the current implementation of the `Data(contentsOf:options:)` initializer, it is not possible to detect if the file was mapped or not.
        // Therefore the mapped and unmapped data will look exactly the same, and no assertions can be made on the data.
        //
        // Ref: https://github.com/swiftlang/swift-foundation/blob/c64dcd8347554db347492e0643d1e5fbc4ccfd2b/Sources/FoundationEssentials/Data/Data%2BReading.swift#L333-L337

        // Assert expected implementation behavior by writing the same file twice without the option set.
        let unmappedData = try Data(contentsOf: fixture.fileUrlToRead)
        let mappedData = try Data(contentsOf: fixture.fileUrlToRead, options: [.alwaysMapped])
        XCTAssertEqual(unmappedData, expectedData)
        XCTAssertEqual(mappedData, expectedData)

        // -- Act --
        let unmappedSentryData = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead)
        let mappedSentryData = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead, options: [.alwaysMapped])

        // -- Assert --
        XCTAssertEqual(unmappedSentryData, expectedData)
        XCTAssertEqual(mappedSentryData, expectedData)
    }

    func testInitContentsOfWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try Data(contentsOfWithSentryTracing: fixture.invalidFileUrlToRead))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToRead.path)
        XCTAssertNil(span.data["file.size"])

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testInitContentsOfWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fixture.nonFileUrl)

        // -- Assert --
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fixture.ignoredFileUrlToRead)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testInitContentsOfWithSentryTracing_SDKIsNotStarted_shouldReadData() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, fixture.data)
    }

    func testInitContentsOfWithSentryTracing_SDKIsClosed_shouldReadData() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // -- Act --
        let data = try Data(contentsOfWithSentryTracing: fixture.fileUrlToRead)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, fixture.data)
    }

    // MARK: - Data.writeWithSentryTracing(to:)

    func testWriteWithSentryTracing_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.fileUrlToWrite.path)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // Reading the written data will create a span, so do it after asserting the transaction
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testWriteWithSentryTracingWithOptions_shouldPassOptionsToSystemImplementation() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)

        // Check pre-condition
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.fileUrlToWrite.path)
        XCTAssertFalse(isFileCreated)

        // To verify that the option is passed, we are using the `withoutOverwriting` option.
        // We expect the default write implementation to not fail when writing the same file twice without the option set.
        // When setting the option, we expect the write operation to fail as the file is already written.

        // Assert expected implementation behavior by writing the same file twice without the option set.
        XCTAssertNoThrow(try sut.write(to: fixture.fileUrlToWrite, options: []))
        XCTAssertNoThrow(try sut.write(to: fixture.fileUrlToWrite, options: []))
        XCTAssertThrowsError(try sut.write(to: fixture.fileUrlToWrite, options: [.withoutOverwriting]))

        // Cleanup by deleting the file
        try FileManager.default.removeItem(at: fixture.fileUrlToWrite)

        // -- Act --
        // The traced implementation should behave the same way as the default implementation.
        XCTAssertNoThrow(try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: []))
        XCTAssertNoThrow(try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: []))
        XCTAssertThrowsError(try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite, options: [.withoutOverwriting]))

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, sut)
    }

    func testWriteWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.writeWithSentryTracing(to: fixture.invalidFileUrlToWrite))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidFileUrlToWrite.path)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testWriteWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        XCTAssertThrowsError(try sut.writeWithSentryTracing(to: fixture.nonFileUrl))

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.ignoredFileUrlToWrite.path)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.ignoredFileUrlToWrite)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.ignoredFileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_SDKIsNotStarted_shouldWriteFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isSDKEnabled: false)
        SentrySDK.close()

        // Check pre-condition
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.fileUrlToWrite.path)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)
    }

    func testWriteWithSentryTracing_SDKIsClosed_shouldWriteFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-condition
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.fileUrlToWrite.path)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        try sut.writeWithSentryTracing(to: fixture.fileUrlToWrite)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, fixture.data)
    }
}
