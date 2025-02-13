@testable import Sentry
import SentryTestUtils
import XCTest

class FileManagerSentryTracingIntegrationTests: XCTestCase {
    private class Fixture {

        let data = "SOME DATA".data(using: .utf8)!

        var fileSrcUrl: URL!
        var fileDestUrl: URL!

        init() {}

        func getSut(testName: String) throws -> FileManager {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("test-\(testName.hashValue.description)")
            try! FileManager.default
                .createDirectory(at: tempDir, withIntermediateDirectories: true)

            fileSrcUrl = tempDir.appendingPathComponent("source-file")
            try data.write(to: fileSrcUrl)

            fileDestUrl = tempDir.appendingPathComponent("destination-file")

            // Initialize the SDK after files are written, so preparations are not traced
            SentrySDK.start { options in
                options.enableSwizzling = true
                options.enableAutoPerformanceTracing = true
                options.enableFileIOTracing = true
                options.tracesSampleRate = 1.0
                options.setIntegrations([SentryFileIOTrackingIntegration.self])
            }

            return FileManager.default
        }

        var fileSrcPath: String { fileSrcUrl.path }
        var invalidSrcUrl: URL { URL(fileURLWithPath: "/path/that/does/not/exist") }
        var invalidSrcPath: String { invalidSrcUrl.path }

        var fileDestPath: String { fileDestUrl.path }
        var invalidDestUrl: URL { URL(fileURLWithPath: "/path/that/does/not/exist") }
        var invalidDestPath: String { invalidDestUrl.path }

        var fileUrlToDelete: URL { fileSrcUrl }
        var filePathToDelete: String { fileUrlToDelete.path }
        var invalidUrlToDelete: URL { invalidSrcUrl }
        var invalidPathToDelete: String { invalidSrcPath }

        var fileUrlToCreate: URL { fileDestUrl }
        var filePathToCreate: String { fileUrlToCreate.path }
        var invalidUrlToCreate: URL { invalidDestUrl }
        var invalidPathToCreate: String { invalidDestPath }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    // MARK: - FileManager.createFileWithSentryTracing(atPath:contents:attributes:)

    func testCreateFileWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.filePathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.filePathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)

        // Reading the written data will create a span, so do it after asserting the transaction
        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)
    }

    func testCreateFileWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // -- Act --
        let result = sut.createFileWithSentryTracing(atPath: fixture.invalidPathToCreate, contents: fixture.data)

        // -- Assert --
        XCTAssertFalse(result)
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileWrite)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidPathToCreate)
        XCTAssertEqual(span.data["file.size"] as? Int, fixture.data.count)
    }

    // MARK: - FileManager.removeItemWithSentryTracing(at:)

    func testRemoveItemWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)
        
        // -- Act --
        try sut.removeItemWithSentryTracing(at: fixture.fileUrlToDelete)

        // -- Assert --
        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileUrlToDelete.path)
    }

    func testRemoveItemWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
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

    // MARK: - FileManager.removeItemWithSentryTracing(atPath:)

    func testRemoveItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        let isFileCreated = FileManager.default.fileExists(atPath: fixture.filePathToDelete)
        XCTAssertTrue(isFileCreated)

        // -- Act --
        try sut.removeItemWithSentryTracing(atPath: fixture.filePathToDelete)

        // -- Assert --
        let isFileRemoved = !FileManager.default.fileExists(atPath: fixture.filePathToDelete)
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
        XCTAssertThrowsError(try sut.removeItemWithSentryTracing(atPath: fixture.invalidSrcPath))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileDelete)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)
    }
    
    // MARK: - FileManager.copyItemWithSentryTracing(at:to:)

    func testCopyItemWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        let srcData = try Data(contentsOf: fixture.fileSrcUrl)
        XCTAssertEqual(srcData, fixture.data)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        let destData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(destData, fixture.data)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)
    }

    func testCopyItemWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.copyItemWithSentryTracing(at: fixture.invalidSrcUrl, to: fixture.invalidDestUrl))

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileCopy)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.invalidSrcPath)
    }

    // MARK: - FileManager.copyItemWithSentryTracing(atPath:toPath:)

    func testCopyItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        // -- Act --
        try sut.copyItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        // Smoke test to ensure the file is written
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        let writtenData = try Data(contentsOf: fixture.fileDestUrl)
        XCTAssertEqual(writtenData, fixture.data)

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

    // MARK: - FileManager.moveItemWithSentryTracing(at:to:)

    func testMoveItemWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertFalse(isDestFileExisting)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcUrl, to: fixture.fileDestUrl)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcUrl.path)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestUrl.path)
        XCTAssertTrue(isDestFileExisting)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcUrl.path)
    }

    func testMoveItemWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
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

    // MARK: - FileManager.moveItemWithSentryTracing(at:to:)

    func testMoveItemAtPathWithSentryTracing_shouldTraceManually() throws {
        // -- Arrange --
        let sut = try fixture.getSut(testName: self.name)
        let parentTransaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer)

        // Smoke test to ensure the file is written
        var isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertTrue(isSrcFileExisting)
        var isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertFalse(isDestFileExisting)

        // -- Act --
        try sut.moveItemWithSentryTracing(at: fixture.fileSrcPath, to: fixture.fileDestPath)

        // -- Assert --
        isSrcFileExisting = FileManager.default.fileExists(atPath: fixture.fileSrcPath)
        XCTAssertFalse(isSrcFileExisting)
        isDestFileExisting = FileManager.default.fileExists(atPath: fixture.fileDestPath)
        XCTAssertTrue(isDestFileExisting)

        XCTAssertEqual(parentTransaction.children.count, 1)
        let span = try XCTUnwrap(parentTransaction.children.first)
        XCTAssertEqual(span.origin, SentryTraceOrigin.manualFileData)
        XCTAssertEqual(span.operation, SentrySpanOperation.fileRename)
        XCTAssertEqual(span.data["file.path"] as? String, fixture.fileSrcPath)
    }

    func testMoveItemAtPathWithSentryTracing_throwsError_shouldTraceManuallyWithErrorRethrow() throws {
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
}
