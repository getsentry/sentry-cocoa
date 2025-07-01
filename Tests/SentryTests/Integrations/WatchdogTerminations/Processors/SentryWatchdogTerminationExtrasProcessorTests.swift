@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationExtrasProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationExtrasProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let scopeExtrasStore: TestSentryScopeExtrasPersistentStore!
        let fileManager: TestFileManager!

        let extras: [String: Any] = [
            "key1": "value1",
            "key2": 123,
            "key3": true
        ]
        let invalidExtras: [String: Any] = [
            "invalid": Double.infinity
        ]

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationExtrasProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
            self.scopeExtrasStore = TestSentryScopeExtrasPersistentStore(fileManager: fileManager)
        }

        func getSut() -> SentryWatchdogTerminationExtrasProcessor {
            SentryWatchdogTerminationExtrasProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeExtrasStore: scopeExtrasStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationExtrasProcessor!

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

    func testInit_fileExistsAtExtrasPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetExtras_whenExtrasIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setExtras(fixture.extras)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetExtras_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
        // The processor is dispatching the file operation on a background queue.
        // This tests checks that the dispatch block is not keeping a strong reference to the
        // processor and causes a retain cycle.

        // -- Arrange --
        // Configure the mock to not execute the block and only keep a reference to the block
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false

        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setExtras(fixture.extras)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set extras, reason: reference to extras processor is nil")
        })
    }

    func testSetExtras_whenExtrasIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setExtras(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetExtras_whenExtrasIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setExtras(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetExtras_whenExtrasIsInvalidJSON_shouldLogErrorAndNotThrow() {
        // -- Arrange --
        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setExtras(fixture.invalidExtras)

        // -- Assert --
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("[error]") && line.contains("Failed to serialize extras, reason: ")
        })
    }

    func testSetExtras_whenExtrasIsInvalidJSON_shouldNotOverwriteExistingFile() throws {
        // -- Arrange --
        let data = Data("Old content".utf8)

        createPersistedFile(data: data)
        assertPersistedFileExists()

        // -- Act --
        sut.setExtras(fixture.invalidExtras)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.scopeExtrasStore.currentFileURL)
        XCTAssertEqual(writtenData, data)
    }

    func testClear_whenExtrasFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenExtrasFileExists_shouldDeleteFileWithoutError() {
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
        FileManager.default.createFile(atPath: fixture.scopeExtrasStore.currentFileURL.path, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopeExtrasStore.currentFileURL.path), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopeExtrasStore.currentFileURL.path), file: file, line: line)
    }
} 
