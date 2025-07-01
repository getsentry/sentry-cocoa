@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationUserProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationUserProcessorTests.self)

    private class Fixture {
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
        let scopeUserStore: TestSentryScopeUserPersistentStore!
        let fileManager: TestFileManager!

        let user: User
        let invalidUser: User

        init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationUserProcessorTests.dsn

            self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            self.fileManager = try TestFileManager(options: Options())
            self.scopeUserStore = TestSentryScopeUserPersistentStore(fileManager: fileManager)
            
            self.user = User(userId: "user123")
            self.user.email = "test@example.com"
            self.user.username = "testuser"
            self.user.ipAddress = "192.168.1.1"
            
            self.invalidUser = User(userId: "user456")
            self.invalidUser.data = ["invalid": Double.infinity]
        }

        func getSut() -> SentryWatchdogTerminationUserProcessor {
            SentryWatchdogTerminationUserProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeUserStore: scopeUserStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationUserProcessor!

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

    func testInit_fileExistsAtUserPath_shouldDeleteFile() throws {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        let _ = fixture.getSut()

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetUser_whenUserIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setUser(fixture.user)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetUser_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
        sut.setUser(fixture.user)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set user, reason: reference to user processor is nil")
        })
    }

    func testSetUser_whenUserIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile()
        assertPersistedFileExists()

        // -- Act --
        sut.setUser(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetUser_whenUserIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists()

        // -- Act --
        sut.setUser(nil)

        // -- Assert --
        assertPersistedFileNotExists()
    }

    func testSetUser_whenUserIsInvalidJSON_shouldLogErrorAndNotThrow() {
        // -- Arrange --
        // Define a log mock to assert the execution path
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        // -- Act --
        sut.setUser(fixture.invalidUser)

        // -- Assert --
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("[error]") && line.contains("Failed to serialize user, reason: ")
        })
    }

    func testSetUser_whenUserIsInvalidJSON_shouldNotOverwriteExistingFile() throws {
        // -- Arrange --
        let data = Data("Old content".utf8)

        createPersistedFile(data: data)
        assertPersistedFileExists()

        // -- Act --
        sut.setUser(fixture.invalidUser)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.scopeUserStore.currentFileURL)
        XCTAssertEqual(writtenData, data)
    }

    func testClear_whenUserFileExistsNot_shouldNotThrow() {
        // -- Arrange --
        // Assert the preconditions
        assertPersistedFileNotExists()

        // -- Act --
        sut.clear()

        // -- Assert --
        assertPersistedFileNotExists()
    }
    
    func testClear_whenUserFileExists_shouldDeleteFileWithoutError() {
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
        FileManager.default.createFile(atPath: fixture.scopeUserStore.currentFileURL.path, contents: data)
    }

    fileprivate func assertPersistedFileExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopeUserStore.currentFileURL.path), file: file, line: line)
    }

    fileprivate func assertPersistedFileNotExists(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopeUserStore.currentFileURL.path), file: file, line: line)
    }
}
