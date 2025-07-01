@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationEnvironmentProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationEnvironmentProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let scopeEnvironmentStore: TestSentryScopeEnvironmentPersistentStore!
        let fileManager: TestFileManager!

        let environment: String = "production"
        let emptyEnvironment: String = ""

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationEnvironmentProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
            self.scopeEnvironmentStore = TestSentryScopeEnvironmentPersistentStore(fileManager: fileManager)
        }

        func getSut() -> SentryWatchdogTerminationEnvironmentProcessor {
            SentryWatchdogTerminationEnvironmentProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeEnvironmentStore: scopeEnvironmentStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationEnvironmentProcessor!

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

    func testInit_fileExistsAtEnvironmentPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetEnvironment_whenEnvironmentIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setEnvironment(fixture.environment)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetEnvironment_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
        sut.setEnvironment(fixture.environment)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set environment, reason: reference to environment processor is nil")
        })
    }

    func testSetEnvironment_whenEnvironmentIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetEnvironment_whenEnvironmentIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetEnvironment_whenEnvironmentIsEmptyString_shouldWriteToDisk() {
        // -- Act --
        sut.setEnvironment(fixture.emptyEnvironment)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testClear_whenEnvironmentFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenEnvironmentFileExists_shouldDeleteFileWithoutError() {
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
        FileManager.default.createFile(atPath: fixture.scopeEnvironmentStore.currentFileURL.path, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopeEnvironmentStore.currentFileURL.path), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopeEnvironmentStore.currentFileURL.path), file: file, line: line)
    }
} 
