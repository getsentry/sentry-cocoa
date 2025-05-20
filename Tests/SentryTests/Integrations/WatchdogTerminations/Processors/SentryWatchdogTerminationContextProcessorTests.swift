@testable import Sentry
import SentryTestUtils
import XCTest

class SentryWatchdogTerminationContextProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnAsString(username: "SentryWatchdogTerminationContextProcessorTests")

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let fileManager: TestFileManager!

        let context: [String: Any] = [
            "name": "Test",
            "operation": "TestOperation",
            "origin": "TestOrigin",
            "description": "TestDescription",
            "data": [
                "key": "value"
            ]
        ]
        let invalidContext: [String: Any] = [
            "key": Double.infinity
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
                fileManager: fileManager
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
        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePathOne, contents: Data())
        XCTAssertTrue(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
    }

    func testInit_fileExistsNotAtActiveFilePath_shouldDeleteFile() throws {
        // -- Arrange --
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))
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
        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePathOne, contents: Data())
        XCTAssertTrue(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
    }

    func testSetContext_whenContextIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
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

        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePathOne, contents: data)
        XCTAssertTrue(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.setContext(fixture.invalidContext)

        // -- Assert --
        let writtenData = try Data(contentsOf: URL(fileURLWithPath: fixture.fileManager.contextFilePathOne))
        XCTAssertEqual(writtenData, data)
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))
    }

    func testClear_whenNoFilesExist_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))
    }

    func testClear_onlyContextFileOneExists_shouldDeleteContextFileOneWithoutError() {
        // -- Arrange --
        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePathOne, contents: Data())
        XCTAssertTrue(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))
    }

    func testClear_onlyContextFileTwoExists_shouldDeleteContextFileTwoWithoutError() {
        // -- Arrange --
        let fm = FileManager.default
        fm.createFile(atPath: fixture.fileManager.contextFilePathTwo, contents: Data())
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertTrue(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathOne))
        XCTAssertFalse(fm.fileExists(atPath: fixture.fileManager.contextFilePathTwo))
    }
}
