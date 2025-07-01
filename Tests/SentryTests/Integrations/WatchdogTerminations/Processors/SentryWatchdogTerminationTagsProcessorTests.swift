@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationTagsProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationTagsProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let scopeTagsStore: TestSentryScopeTagsPersistentStore!
        let fileManager: TestFileManager!

        let validTags: [String: String]

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationTagsProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
            self.scopeTagsStore = TestSentryScopeTagsPersistentStore(fileManager: fileManager)
            
            self.validTags = [
                "environment": "production",
                "version": "1.0.0",
                "user_id": "12345"
            ]
        }

        func getSut() -> SentryWatchdogTerminationTagsProcessor {
            SentryWatchdogTerminationTagsProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeTagsStore: scopeTagsStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTagsProcessor!

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

    func testInit_fileExistsAtTagsPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTags_whenTagsAreValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setTags(fixture.validTags)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetTags_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
        sut.setTags(fixture.validTags)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set tags, reason: reference to tags processor is nil")
        })
    }

    func testSetTags_whenTagsAreNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setTags(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTags_whenTagsAreNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setTags(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetTags_whenTagsAreEmpty_shouldDispatchToQueue() {
        // -- Act --
        sut.setTags([:])

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testClear_whenTagsFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenTagsFileExists_shouldDeleteFileWithoutError() {
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

    func testSetTags_whenTagsContainSpecialCharacters_shouldDispatchToQueue() {
        // -- Arrange --
        let tagsWithSpecialChars = [
            "key_with_spaces": "value with spaces",
            "key-with-dashes": "value-with-dashes",
            "key_with_unicode": "value with émojis 🚀",
            "key_with_numbers": "value123"
        ]

        // -- Act --
        sut.setTags(tagsWithSpecialChars)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetTags_whenTagsAreLarge_shouldDispatchToQueue() {
        // -- Arrange --
        let largeTags = [
            "large_key_1": String(repeating: "a", count: 1_000),
            "large_key_2": String(repeating: "b", count: 1_000),
            "large_key_3": String(repeating: "c", count: 1_000)
        ]

        // -- Act --
        sut.setTags(largeTags)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    // MARK: - Assertion Helpers

    fileprivate func createPersistedFile(data: Data = Data(), file: StaticString = #file, line: UInt = #line) {
        FileManager.default.createFile(atPath: fixture.scopeTagsStore.currentFileURL.path, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopeTagsStore.currentFileURL.path), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopeTagsStore.currentFileURL.path), file: file, line: line)
    }
} 
