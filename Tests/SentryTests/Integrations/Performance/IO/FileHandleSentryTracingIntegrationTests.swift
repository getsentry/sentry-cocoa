// swiftlint:disable file_length
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class FileHandleSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {
        let mockDateProvider: TestCurrentDateProvider = {
            let provider = TestCurrentDateProvider()
            provider.driftTimeForEveryRead = true
            provider.driftTimeInterval = 0.25
            return provider
        }()

        let data = Data("SOME DATA".utf8)

        var fileUrlToRead: URL!
        var fileUrlToWrite: URL!
        var ignoredFileUrlToRead: URL!
        var ignoredFileUrlToWrite: URL!
        var fileHandleToRead: FileHandle?
        var fileHandleToWrite: FileHandle?
        var ignoredFileHandleToRead: FileHandle?
        var ignoredFileHandleToWrite: FileHandle?

        init() {}

        func getSut(testName: String, isSDKEnabled: Bool = true, isEnabled: Bool = true) throws -> Data {
            let fileManager = FileManager.default
            let tempDirUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try fileManager
                .createDirectory(at: tempDirUrl, withIntermediateDirectories: true)

            if isSDKEnabled {
                SentryDependencyContainer.sharedInstance().dateProvider = mockDateProvider

                SentrySDK.start { options in
                    options.dsn = TestConstants.dsnAsString(username: testName)
                    options.removeAllIntegrations()

                    // Configure options required by File I/O tracking integration
                    options.enableAutoPerformanceTracing = true
                    options.enableFileIOTracing = isEnabled

                    // Configure the tracing sample rate to record all traces
                    options.tracesSampleRate = 1.0

                    // NOTE: We are not testing for the case where swizzling is enabled, as it could lead to duplicate spans on older OS versions.
                    // Instead we are recommending to disable swizzling and use manual tracing.
                    options.enableSwizzling = true
                    options.enableDataSwizzling = false
                    options.enableFileManagerSwizzling = false
                    options.enableFileHandleSwizzling = false
                }

                // The base path is not unique for the DSN, therefore we need to make it unique
                fileUrlToRead = tempDirUrl.appendingPathComponent("test-\(testName.hashValue.description)--file-to-read")
                try data.write(to: fileUrlToRead)
                fileHandleToRead = try FileHandle(forReadingFrom: fileUrlToRead)

                fileUrlToWrite = tempDirUrl.appendingPathComponent("test-\(testName.hashValue.description)--file-to-write")
                if fileManager.fileExists(atPath: fileUrlToWrite.path) {
                    try fileManager.removeItem(at: fileUrlToWrite)
                }
                FileManager.default.createFile(atPath: fileUrlToWrite.path, contents: nil)
                fileHandleToWrite = try FileHandle(forWritingTo: fileUrlToWrite)

                // Get the working directory of the SDK, as these files are ignored by default
                guard let sentryPath = SentrySDKInternal.currentHub().getClient()?.fileManager.sentryPath else {
                    preconditionFailure("Sentry path is nil, but should be configured for test cases.")
                }
                let sentryPathUrl = URL(fileURLWithPath: sentryPath)

                ignoredFileUrlToRead = sentryPathUrl.appendingPathComponent("test--ignored-file-to-read")
                try data.write(to: ignoredFileUrlToRead)
                ignoredFileHandleToRead = try FileHandle(forReadingFrom: ignoredFileUrlToRead)

                ignoredFileUrlToWrite = sentryPathUrl.appendingPathComponent("test--ignored-file-to-write")
                if fileManager.fileExists(atPath: ignoredFileUrlToWrite.path) {
                    try fileManager.removeItem(at: ignoredFileUrlToWrite)
                }
                FileManager.default.createFile(atPath: ignoredFileUrlToWrite.path, contents: nil)
                ignoredFileHandleToWrite = try FileHandle(forWritingTo: ignoredFileUrlToWrite)
            } else {
                fileUrlToRead = tempDirUrl.appendingPathComponent("file-to-read")
                try data.write(to: fileUrlToRead)
                fileHandleToRead = try FileHandle(forReadingFrom: fileUrlToRead)

                fileUrlToWrite = tempDirUrl.appendingPathComponent("file-to-write")
                if fileManager.fileExists(atPath: fileUrlToWrite.path) {
                    try fileManager.removeItem(at: fileUrlToWrite)
                }
                FileManager.default.createFile(atPath: fileUrlToWrite.path, contents: nil)
                fileHandleToWrite = try FileHandle(forWritingTo: fileUrlToWrite)
            }
            return data
        }

        var invalidFileUrlToRead: URL {
            URL(fileURLWithPath: "/dev/null")
        }

        func tearDown() throws {
            clearTestState()

            // Close file handles
            try? fileHandleToRead?.close()
            try? fileHandleToWrite?.close()
            try? ignoredFileHandleToRead?.close()
            try? ignoredFileHandleToWrite?.close()

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

    // MARK: - FileHandle.readDataWithSentryTracing(ofLength:)

    func testReadDataWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let data = try fileHandle.readDataWithSentryTracing(ofLength: expectedData.count)

        // -- Assert --
        XCTAssertEqual(data, expectedData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        }
        XCTAssertEqual(span.data["file.size"] as? Int, expectedData.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testReadDataWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.close()

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try fileHandle.readDataWithSentryTracing(ofLength: 10))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        }

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testReadDataWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataWithSentryTracing(ofLength: expectedData.count)

        // -- Assert --
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testReadDataWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.ignoredFileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataWithSentryTracing(ofLength: fixture.data.count)

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testReadDataWithSentryTracing_SDKIsNotStarted_shouldReadData() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name, isSDKEnabled: false)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataWithSentryTracing(ofLength: expectedData.count)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, expectedData)
    }

    func testReadDataWithSentryTracing_SDKIsClosed_shouldReadData() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)
        SentrySDK.close()
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataWithSentryTracing(ofLength: expectedData.count)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, expectedData)
    }

    // MARK: - FileHandle.readDataToEndOfFileWithSentryTracing()

    func testReadDataToEndOfFileWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let data = try fileHandle.readDataToEndOfFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(data, expectedData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        }
        XCTAssertEqual(span.data["file.size"] as? Int, expectedData.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testReadDataToEndOfFileWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.close()

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try fileHandle.readDataToEndOfFileWithSentryTracing())

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRead)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToRead.path)
        }

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testReadDataToEndOfFileWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataToEndOfFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testReadDataToEndOfFileWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.ignoredFileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataToEndOfFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(data, fixture.data)
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testReadDataToEndOfFileWithSentryTracing_SDKIsNotStarted_shouldReadData() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name, isSDKEnabled: false)
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataToEndOfFileWithSentryTracing()

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, expectedData)
    }

    func testReadDataToEndOfFileWithSentryTracing_SDKIsClosed_shouldReadData() throws {
        // -- Arrange --
        let expectedData = try fixture.getSut(testName: self.name)
        SentrySDK.close()
        guard let fileHandle = fixture.fileHandleToRead else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        let data = try fileHandle.readDataToEndOfFileWithSentryTracing()

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertEqual(data, expectedData)
    }

    // MARK: - FileHandle.writeWithSentryTracing(_:)

    func testWriteWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }

        // Check pre-condition
        let initialData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(initialData.count, 0)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try fileHandle.writeWithSentryTracing(sut)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        }
        XCTAssertEqual(span.data["file.size"] as? Int, sut.count)

        // Reading the written data will create a span, so do it after asserting the transaction
        try fileHandle.synchronizeFile()
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, sut)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testWriteWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.close()

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try fileHandle.writeWithSentryTracing(sut))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        }
        XCTAssertEqual(span.data["file.size"] as? Int, sut.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testWriteWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        try fileHandle.writeWithSentryTracing(sut)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.ignoredFileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        try fileHandle.writeWithSentryTracing(sut)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testWriteWithSentryTracing_SDKIsNotStarted_shouldWriteFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isSDKEnabled: false)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        try fileHandle.writeWithSentryTracing(sut)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        try fileHandle.synchronizeFile()
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, sut)
    }

    func testWriteWithSentryTracing_SDKIsClosed_shouldWriteFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        SentrySDK.close()
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }

        // -- Act --
        try fileHandle.writeWithSentryTracing(sut)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        try fileHandle.synchronizeFile()
        let writtenData = try Data(contentsOf: fixture.fileUrlToWrite)
        XCTAssertEqual(writtenData, sut)
    }

    // MARK: - FileHandle.synchronizeFileWithSentryTracing()

    func testSynchronizeFileWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.write(sut)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try fileHandle.synchronizeFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.ok)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        }

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testSynchronizeFileWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let _ = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.close()

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try fileHandle.synchronizeFileWithSentryTracing())

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)

        XCTAssertEqual(span.status, SentrySpanStatus.internalError)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToWrite.path)
        }

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testSynchronizeFileWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.write(sut)

        // -- Act --
        try fileHandle.synchronizeFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testSynchronizeFileWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        guard let fileHandle = fixture.ignoredFileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.write(sut)

        // -- Act --
        try fileHandle.synchronizeFileWithSentryTracing()

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testSynchronizeFileWithSentryTracing_SDKIsNotStarted_shouldSynchronizeFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name, isSDKEnabled: false)
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.write(sut)

        // -- Act --
        try fileHandle.synchronizeFileWithSentryTracing()

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
    }

    func testSynchronizeFileWithSentryTracing_SDKIsClosed_shouldSynchronizeFile() throws {
        // -- Arrange --
        let sut: Data = try fixture.getSut(testName: self.name)
        SentrySDK.close()
        guard let fileHandle = fixture.fileHandleToWrite else {
            XCTFail("FileHandle is nil")
            return
        }
        try fileHandle.write(sut)

        // -- Act --
        try fileHandle.synchronizeFileWithSentryTracing()

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
    }
}
// swiftlint:enable file_length
