@testable import Sentry
import SentryTestUtils
import XCTest

class SentryWatchdogTerminationContextProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationContextProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let fileManager: TestFileManager!

        let context: [String: [String: Any]] = [
            "app": [
                "id": 123,
                "name": "TestApp"
            ],
            "device": [
                "device.class": "iPhone",
                "os": "iOS"
            ]
        ]
        let invalidContext: [String: [String: Any]] = [
            "other": [
                "key": Double.infinity
            ]
        ]

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationContextProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
        }

        func getSut() -> SentryWatchdogTerminationContextProcessor {
            SentryWatchdogTerminationContextProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeContextStore: SentryScopeContextPersistentStore(fileManager: fileManager)
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationContextProcessor!

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

    func testInit_fileExistsAtContextPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetContext_whenContextIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setContext(fixture.context)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetContext_whenProcessorIsDeallocatedWhileDispatching_shouldNotCrash() {
        // -- Arrange --
        // Configure the mock to not execute the block and only keep a reference to the block
        fixture.dispatchQueueWrapper.dispatchAsyncExecutesBlock = false

        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setContext(fixture.context)
        sut = nil

        // Execute the block after the processor is deallocated
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set context, reason: reference to context processor is nil")
        })
    }

    func testSetContext_whenContextIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetContext_whenContextIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetContext_whenContextIsInvalidJSON_shouldLogErrorAndNotThrow() {
        // -- Arrange --
        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setContext(fixture.invalidContext)

        // -- Assert --
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("[error]") && line.contains("Failed to serialize context, reason: ")
        })
    }

    func testSetContext_whenContextIsInvalidJSON_shouldNotOverwriteExistingFile() throws {
        // -- Arrange --
        let data = Data("Old content".utf8)

        createPersistedFile(data: data)
        assertPersistedFileExists()

        // -- Act --
        sut.setContext(fixture.invalidContext)

        // -- Assert --
        let writtenData = try Data(contentsOf: URL(fileURLWithPath: fixture.fileManager.contextFilePath))
        XCTAssertEqual(writtenData, data)
    }

    func testClear_whenContextFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenContextFileExists_shouldDeleteFileWithoutError() {
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
        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePath, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.fileManager.contextFilePath), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.contextFilePath), file: file, line: line)
    }
}
