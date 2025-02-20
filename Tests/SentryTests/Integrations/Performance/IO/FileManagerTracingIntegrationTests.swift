@testable import Sentry
import SentryTestUtils
import XCTest

class FileManagerSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {

        let data = "SOME DATA".data(using: .utf8)!

        var fileSrcUrl: URL!
        var fileDestUrl: URL!
        var ignoredFileToDeleteUrl: URL!
        var ignoredFileToCreateUrl: URL!
        var ignoredSrcFileUrl: URL!

        init() {}

        func getSut(testName: String, isEnabled: Bool = true) throws -> FileManager {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try! FileManager.default
                .createDirectory(at: tempDir, withIntermediateDirectories: true)

            fileSrcUrl = tempDir.appendingPathComponent("source-file")
            try data.write(to: fileSrcUrl)

            fileDestUrl = tempDir.appendingPathComponent("destination-file")

            // Initialize the SDK after files are written, so preparations are not traced
            SentrySDK.start { options in
                options.removeAllIntegrations()

                // Configure options required by File I/O tracking integration
                options.enableAutoPerformanceTracing = true
                options.enableFileIOTracing = isEnabled
                options.setIntegrations(isEnabled ? [SentryFileIOTrackingIntegration.self] : [])

                // Configure the tracing sample rate to record all traces
                options.tracesSampleRate = 1.0

                // NOTE: We are not testing for the case where swizzling is enabled, as it could lead to duplicate spans on older OS versions.
                // Instead we are recommending to disable swizzling and use manual tracing.
                options.enableSwizzling = false

                // Configure the cache directory to a temporary directory, so we can isolate the test files
                options.cacheDirectoryPath = tempDir.path
            }

            // Get the working directory of the SDK, as these files are ignored by default
            let sentryPath = SentrySDK.currentHub().getClient()!.fileManager.sentryPath
            ignoredFileToCreateUrl = URL(fileURLWithPath: sentryPath).appendingPathComponent("ignored-file-to-create")

            ignoredFileToDeleteUrl = URL(fileURLWithPath: sentryPath).appendingPathComponent("ignored-file-to-delete")
            try data.write(to: ignoredFileToDeleteUrl)

            ignoredSrcFileUrl = URL(fileURLWithPath: sentryPath).appendingPathComponent("ignored-src-file")
            try data.write(to: ignoredSrcFileUrl)

            return FileManager.default
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

    // MARK: - FileManager.createFileWithSentryTracing(atPath:contents:attributes:)

    func testCreateFileAtPathWithSentryTracing_withoutData_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: nil)

        // -- Assert --
        XCTAssertTrue(result)

        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)

        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData.count, 0)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertNil(span.data["file.size"])
    }

    func testCreateFileAtPathWithSentryTracing_withData_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertTrue(result)

        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)

        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
    }

    func testCreateFileAtPathWithSentryTracing_failsToCreateFile_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Check pre-condition
        var isFileCreated = FileManager.default.fileExists(atPath: fixture.invalidPathToCreate)
        XCTAssertFalse(isFileCreated)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.invalidPathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertFalse(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertFalse(isFileCreated)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidPathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
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
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToCreate)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)

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
        XCTAssertTrue(result)
        isFileCreated = FileManager.default.fileExists(atPath: fixture.ignoredFileToCreatePath)
        XCTAssertTrue(isFileCreated)
        let writtenData = try Data(contentsOf: fixture.ignoredFileToCreateUrl)
        XCTAssertEqual(writtenData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 0)
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
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToDelete.path)
    }

    func testRemoveItemAtUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(at: fixture.invalidUrlToDelete))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidPathToDelete)
    }

    func testRemoveItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // -- Act --
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(at: fixture.nonFileUrl))

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
    }
    
    func testRemoveItemAtUrlWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name, isEnabled: false)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // Check-precondition
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

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
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeleteUrl.path)
        XCTAssertTrue(isFileRemoved)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    // MARK: - FileManager.removeItemWithSentryTracing(atPath:)

    func testRemoveItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        var isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertFalse(isFileRemoved)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)
    }

    func testRemoveItemAtPathWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(atPath: fixture.invalidPathToDelete))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)
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
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileRemoved)

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
        isFileRemoved = !FileManager.default.fileExists(atPath: fixture.ignoredFileToDeletePath)
        XCTAssertTrue(isFileRemoved)

        XCTAssertEqual(parentTransaction.children.count, 0)
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
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)
    }

    func testCopyItemAtUrlWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.invalidSrcUrl, to: fixture.invalidDestUrl))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcUrl.path)
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
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

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
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testCopyItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.nonFileUrl, to: fixture.fileDestUrl))

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
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
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        // Smoke test to ensure the file is written
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)
    }

    func testCopyItemAtPathWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.invalidSrcPath, to: fixture.invalidDestPath))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)
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
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

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
        try sut.copyItemWithSentryTracing(at: fixture.ignoredSrcFilePath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 0)
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
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)
    }

    func testMoveItemAtUrlWithSentryTracing_throwsError_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(at: fixture.invalidSrcUrl, to: fixture.invalidDestUrl))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcUrl.path)
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
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

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
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFileUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }

    func testMoveItemAtUrlWithSentryTracing_nonFileUrl_shouldNotTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(at: fixture.nonFileUrl, to: fixture.fileDestUrl))

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 0)
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
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)
    }

    func testMoveItemAtPathWithSentryTracing_throwsError_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.moveItemWithSentryTracing(at: fixture.invalidSrcPath, to: fixture.invalidDestPath))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)
    }

    func testMoveItemAtPathWithSentryTracing_trackerIsNotEnabled_shouldNotTraceManually() throws {
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
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

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
        try sut.moveItemWithSentryTracing(at: fixture.ignoredSrcFilePath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.ignoredSrcFilePath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, srcData)

        XCTAssertEqual(parentTransaction.children.count, 0)
    }
}
