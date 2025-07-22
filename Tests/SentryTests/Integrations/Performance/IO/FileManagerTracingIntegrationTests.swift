// swiftlint:disable file_length
@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class FileManagerSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {
        let mockDateProvider: TestCurrentDateProvider = {
            let provider = TestCurrentDateProvider()
            provider.driftTimeForEveryRead = true
            provider.driftTimeInterval = 0.25
            return provider
        }()

        let data = Data("SOME DATA".utf8)

        var fileSrcUrl: URL!
        var fileDestUrl: URL!
        var ignoredFileToDeleteUrl: URL!
        var ignoredFileToCreateUrl: URL!
        var ignoredSrcFileUrl: URL!

        init() {}

        func getSut(testName: String, isSDKEnabled: Bool = true, isEnabled: Bool = true) throws -> FileManager {
            if isSDKEnabled {
                return try getSutWithEnabledSDK(testName: testName, isEnabled: isEnabled)
            }
            return try getSutWithDisabledSDK(testName: testName, isEnabled: isEnabled)
        }

        private func getSutWithEnabledSDK(testName: String, isEnabled: Bool) throws -> FileManager {
            let fileManager = FileManager.default
            SentryDependencyContainer.sharedInstance().dateProvider = mockDateProvider

            SentrySDK.start { options in
                options.dsn = TestConstants.dsnAsString(username: "FileManagerSentryTracingIntegrationTests")
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
            let sentryBasePath = try XCTUnwrap(SentrySDKInternal.currentHub().getClient()?.fileManager.basePath, "Sentry base path is nil, but should be configured for test cases.")
            let sentryBasePathUrl = URL(fileURLWithPath: sentryBasePath)

            // The base path is not unique for the DSN, therefore we need to make it unique
            fileSrcUrl = sentryBasePathUrl.appendingPathComponent("test-\(testName.hashValue.description)-source-file")
            try data.write(to: fileSrcUrl)

            fileDestUrl = sentryBasePathUrl.appendingPathComponent("test-\(testName.hashValue.description)-destination-file")
            if fileManager.fileExists(atPath: fileDestUrl.path) {
                try fileManager.removeItem(at: fileDestUrl)
            }

            // Get the working directory of the SDK, as these files are ignored by default
            let sentryPath = try XCTUnwrap(SentrySDKInternal.currentHub().getClient()?.fileManager.sentryPath, "Sentry path is nil, but should be configured for test cases.")
            let sentryPathUrl = URL(fileURLWithPath: sentryPath)

            ignoredFileToCreateUrl = sentryPathUrl.appendingPathComponent("test--ignored-file-to-create")
            if fileManager.fileExists(atPath: ignoredFileToCreateUrl.path) {
                try fileManager.removeItem(at: ignoredFileToCreateUrl)
            }

            ignoredFileToDeleteUrl = sentryPathUrl.appendingPathComponent("test--ignored-file-to-delete")
            try data.write(to: ignoredFileToDeleteUrl)

            ignoredSrcFileUrl = sentryPathUrl.appendingPathComponent("test--ignored-src-file")
            try data.write(to: ignoredSrcFileUrl)

            return fileManager
        }

        private func getSutWithDisabledSDK(testName: String, isEnabled: Bool) throws -> FileManager {
            let fileManager = FileManager.default

            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try! FileManager.default
                .createDirectory(at: tempDir, withIntermediateDirectories: true)

            fileSrcUrl = tempDir.appendingPathComponent("source-file")
            try data.write(to: fileSrcUrl)

            fileDestUrl = tempDir.appendingPathComponent("destination-file")
            if fileManager.fileExists(atPath: fileDestUrl.path) {
                try fileManager.removeItem(at: fileDestUrl)
            }

            return fileManager
        }

        var fileSrcPath: String { fileSrcUrl.path }
        var invalidSrcUrl: URL { URL(fileURLWithPath: "/path/that/does/not/exist") }
        var invalidSrcPath: String { invalidSrcUrl.path }
        var ignoredSrcFilePath: String { ignoredSrcFileUrl.path }

        var fileDestPath: String { fileDestUrl.path }
        var invalidDestUrl: URL { URL(fileURLWithPath: "/path/that/does/not/exist") }
        var invalidDestPath: String { invalidDestUrl.path }

        var fileUrlToDelete: URL { fileSrcUrl }
        var filePathToDelete: String { fileUrlToDelete.path }
        var invalidUrlToDelete: URL { invalidSrcUrl }
        var invalidPathToDelete: String { invalidSrcPath }

        var filePathToCreate: String { fileDestUrl.path }
        var invalidPathToCreate: String { invalidDestPath }

        var nonFileUrl: URL {
            // URL to a file that is not a file but should exist at all times
            URL(string: "https://raw.githubusercontent.com/getsentry/sentry-cocoa/refs/heads/main/.gitignore")!
        }

        var ignoredFileToCreatePath: String {
            ignoredFileToCreateUrl.path
        }

        var ignoredFileToDeletePath: String {
            ignoredFileToDeleteUrl.path
        }

        func tearDown() throws {
            clearTestState()

            // Delete files created by the test run
            let manager = FileManager.default
            if fileSrcUrl != nil && manager.fileExists(atPath: fileSrcUrl.path) {
                try manager.removeItem(at: fileSrcUrl)
            }
            if fileDestUrl != nil && manager.fileExists(atPath: fileDestUrl.path) {
                try manager.removeItem(at: fileDestUrl)
            }
            if ignoredFileToDeleteUrl != nil && manager.fileExists(atPath: ignoredFileToDeleteUrl.path) {
                try manager.removeItem(at: ignoredFileToDeleteUrl)
            }
            if ignoredFileToCreateUrl != nil && manager.fileExists(atPath: ignoredFileToCreateUrl.path) {
                try manager.removeItem(at: ignoredFileToCreateUrl)
            }
            if ignoredSrcFileUrl != nil && manager.fileExists(atPath: ignoredSrcFileUrl.path) {
                try manager.removeItem(at: ignoredSrcFileUrl)
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

    // MARK: - FileManager.createFileWithSentryTracing(atPath:contents:attributes:)

    func testCreateFileAtPathWithSentryTracing_withoutDataOrAttributes_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Create the file to get the default attributes of the system implementation
        XCTAssertTrue(FileManager.default.createFile(atPath: fixture.filePathToCreate, contents: nil))
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        try FileManager.default.removeItem(atPath: fixture.filePathToCreate)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: nil)

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData.count, 0)
        let writtenAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        // Note: We are not comparing the values, as they will mostly differ (date of creation, file system node, etc.)
        XCTAssertEqual(writtenAttributes.keys, expectedAttributes.keys)

        // Assert the span created by the file
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertNil(span.data["file.size"])

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCreateFileAtPathWithSentryTracing_withDataAndWithoutAttributes_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Create the file to get the default attributes of the system implementation
        XCTAssertTrue(FileManager.default.createFile(atPath: fixture.filePathToCreate, contents: nil))
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        try FileManager.default.removeItem(atPath: fixture.filePathToCreate)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)
        let writtenAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        // Note: We are not comparing the values, as they will mostly differ (date of creation, file system node, etc.)
        XCTAssertEqual(writtenAttributes.keys, expectedAttributes.keys)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCreateFileAtPathWithSentryTracing_withDataAndWithAttributes_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Create the file to get the default attributes of the system implementation
        XCTAssertTrue(FileManager.default.createFile(atPath: fixture.filePathToCreate, contents: nil))
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        try FileManager.default.removeItem(atPath: fixture.filePathToCreate)
        XCTAssertNotEqual(expectedAttributes[FileAttributeKey.creationDate] as? Date, Date(timeIntervalSince1970: 30_000))

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let result = sut.createFileWithSentryTracing(
            atPath: fixture.filePathToCreate,
            contents: fixture.data,
            attributes: [.creationDate: Date(timeIntervalSince1970: 30_000)]
        )

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)
        let writtenAttributes = try FileManager.default.attributesOfItem(atPath: fixture.fileDestPath)
        XCTAssertEqual(writtenAttributes[FileAttributeKey.creationDate] as? Date, Date(timeIntervalSince1970: 30_000))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCreateFileAtPathWithSentryTracing_failsToCreateFile_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.invalidPathToCreate)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        let result = sut.createFileWithSentryTracing(atPath: fixture.invalidPathToCreate, contents: fixture.data)

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertFalse(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidPathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCreateFileAtPathWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCreateFileAtPathWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.ignoredFileToCreatePath)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.ignoredFileToCreatePath, contents: fixture.data)

        // -- Assert --
        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.ignoredFileToCreatePath)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.ignoredFileToCreateUrl)
        XCTAssertEqual(writtenData, fixture.data)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCreateFileAtPathWithSentryTracing_SDKIsNotStarted_shouldCreateFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Create the file to get the default attributes of the system implementation
        XCTAssertTrue(FileManager.default.createFile(atPath: fixture.filePathToCreate, contents: nil))
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        try FileManager.default.removeItem(atPath: fixture.filePathToCreate)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertTrue(result)

        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData.count, fixture.data.count)
        let writtenAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        // Note: We are not comparing the values, as they will mostly differ (date of creation, file system node, etc.)
        XCTAssertEqual(writtenAttributes.keys, expectedAttributes.keys)

    }

    func testCreateFileAtPathWithSentryTracing_SDKIsClosed_shouldCreateFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // Create the file to get the default attributes of the system implementation
        XCTAssertTrue(FileManager.default.createFile(atPath: fixture.filePathToCreate, contents: nil))
        let expectedAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        try FileManager.default.removeItem(atPath: fixture.filePathToCreate)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)
        XCTAssertTrue(result)

        // Assert the result of the file operation
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData.count, fixture.data.count)
        let writtenAttributes = try FileManager.default.attributesOfItem(atPath: fixture.filePathToCreate)
        // Note: We are not comparing the values, as they will mostly differ (date of creation, file system node, etc.)
        XCTAssertEqual(writtenAttributes.keys, expectedAttributes.keys)
    }

    // MARK: - FileManager.removeItemWithSentryTracing(at:)

    func testRemoveItemAtUrlWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // Check pre-condition
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        // Assert the result of the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToDelete.path)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testRemoveItemAtUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(at: fixture.invalidUrlToDelete))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidPathToDelete)
    }

    func testRemoveItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // -- Act & Assert --
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(at: fixture.nonFileUrl))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }
    
    func testRemoveItemAtUrlWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // Check-precondition
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act & Assert --
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }
    
    func testRemoveItemAtUrlWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeleteUrl.path)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(at: fixture.ignoredFileToDeleteUrl)

        // -- Assert --
        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeleteUrl.path)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testRemoveItemAtUrlWithSentryTracing_SDKIsNotStarted_shouldRemoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)
    }

    func testRemoveItemAtUrlWithSentryTracing_SDKIsClosed_shouldRemoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)
    }

    // MARK: - FileManager.removeItemWithSentryTracing(atPath:)

    func testRemoveItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testRemoveItemAtPathWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(atPath: fixture.invalidPathToDelete))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testRemoveItemAtPathWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testRemoveItemAtPathWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeletePath)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.ignoredFileToDeletePath)

        // -- Assert --
        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeletePath)
        XCTAssertTrue(isFileRemoved)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testRemoveItemAtPathWithSentryTracing_SDKIsNotStarted_shouldRemoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)
    }

    func testRemoveItemAtPathWithSentryTracing_SDKIsClosed_shouldRemoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)
    }

    // MARK: - FileManager.copyItemWithSentryTracing(at:to:)

    func testCopyItemAtUrlWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, fixture.data)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCopyItemAtUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.invalidSrcUrl, to: fixture.invalidDestUrl))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcUrl.path)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCopyItemAtUrlWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtUrlWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.ignoredSrcFileUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.nonFileUrl, to: fixture.fileDestUrl))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtUrlWithSentryTracing_SDKIsNotStarted_shouldCopyFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert -- 
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, fixture.data)
    }

    func testCopyItemAtUrlWithSentryTracing_SDKIsClosed_shouldCopyFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, fixture.data)
    }
    
    // MARK: - FileManager.copyItemWithSentryTracing(atPath:toPath:)

    func testCopyItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.copyItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCopyItemAtPathWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(atPath: fixture.invalidSrcPath, toPath: fixture.invalidDestPath))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testCopyItemAtPathWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtPathWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(atPath: fixture.ignoredSrcFilePath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtPathWithSentryTracing_SDKIsNotStarted_shouldCopyFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, srcData)
    }

    func testCopyItemAtPathWithSentryTracing_SDKIsClosed_shouldCopyFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, srcData)
    }

    // MARK: - FileManager.moveItemWithSentryTracing(at:to:)

    func testMoveItemAtUrlWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testMoveItemAtUrlWithSentryTracing_throwsError_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(at: fixture.invalidSrcUrl, to: fixture.invalidDestUrl))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcUrl.path)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testMoveItemAtUrlWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtUrlWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.ignoredSrcFileUrl, to: fixture.fileDestUrl)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(at: fixture.nonFileUrl, to: fixture.fileDestUrl))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtUrlWithSentryTracing_SDKIsNotStarted_shouldMoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert -- 
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)
    }

    func testMoveItemAtUrlWithSentryTracing_SDKIsClosed_shouldMoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)
    }

    // MARK: - FileManager.moveItemWithSentryTracing(atPath:toPath:)

    func testMoveItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        let refTimestamp = fixture.mockDateProvider.date()
        try sut.moveItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testMoveItemAtPathWithSentryTracing_throwsError_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        let refTimestamp = fixture.mockDateProvider.date()
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(atPath: fixture.invalidSrcPath, toPath: fixture.invalidDestPath))

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOriginManualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperationFileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)

        // As the date provider is used by multiple internal components, it is not possible to pin-point the exact timestamp.
        // Therefore, we can only assert relative timestamps as the date provider uses an internal drift.
        // The timestamps are tested in the unit tests of the file I/O tracker helper and span tests.
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let endTimestamp = try XCTUnwrap(span.timestamp)
        XCTAssertGreaterThan(startTimestamp.timeIntervalSince1970, refTimestamp.timeIntervalSince1970)
        XCTAssertGreaterThan(endTimestamp.timeIntervalSince1970, startTimestamp.timeIntervalSince1970)
    }

    func testMoveItemAtPathWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        // Assert the file operation
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtPathWithSentryTracing_fileIsIgnored_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(atPath: fixture.ignoredSrcFilePath, toPath: fixture.fileDestPath)

        // -- Assert --
        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        // Assert the span created by the file operation
        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtPathWithSentryTracing_SDKIsNotStarted_shouldMoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isSDKEnabled: false)

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)
    }

    func testMoveItemAtPathWithSentryTracing_SDKIsClosed_shouldMoveFile() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        SentrySDK.close()

        // Check pre-conditions
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.moveItemWithSentryTracing(atPath: fixture.fileSrcPath, toPath: fixture.fileDestPath)

        // -- Assert --
        XCTAssertFalse(SentrySDK.isEnabled)

        // Assert the file operation
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)
    }   
}
// swiftlint:enable file_length
