@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationTraceContextProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationTraceContextProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let scopeTraceContextStore: TestSentryScopeTraceContextPersistentStore!
        let fileManager: TestFileManager!

        let traceContext: [String: Any] = [
            "trace_id": "abc123",
            "span_id": "def456",
            "parent_span_id": "ghi789"
        ]
        let invalidTraceContext: [String: Any] = [
            "invalid": Double.infinity
        ]

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationTraceContextProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
            self.scopeTraceContextStore = TestSentryScopeTraceContextPersistentStore(fileManager: fileManager)
        }

        func getSut() -> SentryWatchdogTerminationTraceContextProcessor {
            SentryWatchdogTerminationTraceContextProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeTraceContextStore: scopeTraceContextStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTraceContextProcessor!

    override func setUpWithError() throws {
        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testInit_fileExistsAtActiveFilePath_shouldDeleteFile() throws {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testInit_fileExistsAtTraceContextPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTraceContext_whenTraceContextIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setTraceContext(fixture.traceContext)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetTraceContext_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
        // The processor is dispatching the file operation on a background queue.
        // This tests checks that the dispatch block is not keeping a strong reference to the
        // processor and causes a retain cycle.

        // -- Arrange --
        // Configure the mock to not execute the block and only keep a reference to the block
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false

        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setTraceContext(fixture.traceContext)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set traceContext, reason: reference to traceContext processor is nil")
        })
    }

    func testSetTraceContext_whenTraceContextIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setTraceContext(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTraceContext_whenTraceContextIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setTraceContext(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTraceContext_whenTraceContextIsInvalidJSON_shouldLogErrorAndNotThrow() {
        // -- Arrange --
        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setTraceContext(fixture.invalidTraceContext)

        // -- Assert --
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("[error]") && line.contains("Failed to serialize traceContext, reason: ")
        })
    }

    func testSetTraceContext_whenTraceContextIsInvalidJSON_shouldNotOverwriteExistingFile() throws {
        // -- Arrange --
        let data = Data("Old content".utf8)

        createPersistedFile(data: data)
        assertPersistedFileExists()

        // -- Act --
        sut.setTraceContext(fixture.invalidTraceContext)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.scopeTraceContextStore.currentFileURL)
        XCTAssertEqual(writtenData, data)
    }

    func testClear_whenTraceContextFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenTraceContextFileExists_shouldDeleteFileWithoutError() {
        // -- Arrange --
        let data = Data("Old content".utf8)
        createPersistedFile(data: data)
        // Assert the preconditions
        assertPersistedFileExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    // MARK: - Assertion Helpers

    fileprivate func createPersistedFile(data: Data = Data(), file: StaticString = #file, line: UInt = #line) {
        FileManager.default.createFile(atPath: fixture.scopeTraceContextStore.currentFileURL.path, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopeTraceContextStore.currentFileURL.path), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopeTraceContextStore.currentFileURL.path), file: file, line: line)
    }
}
