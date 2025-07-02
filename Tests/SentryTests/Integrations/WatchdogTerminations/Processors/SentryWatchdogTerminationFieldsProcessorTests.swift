@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationFieldsProcessorTests: XCTestCase {
   private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationFieldsProcessorTests.self)

   private class Fixture {
       let dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
       let scopePersistentStore: TestSentryScopePersistentStore!
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
       
       let user: User = {
           let user = User(userId: "test-user-id")
           user.email = "test@example.com"
           user.username = "testuser"
           user.name = "Test User"
           user.ipAddress = "192.168.1.1"
           user.data = ["custom_key": "custom_value"]
           return user
       }()
       
       let invalidUser: User = {
           let user = User(userId: "test-user-id")
           // Create an invalid user by setting data with non-serializable content
           user.data = ["invalid_key": Double.infinity]
           return user
       }()

       init() throws {
           let options = Options()
           options.dsn = SentryWatchdogTerminationFieldsProcessorTests.dsn

           self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
           self.fileManager = try TestFileManager(options: Options())
           self.scopePersistentStore = TestSentryScopePersistentStore(fileManager: fileManager)
       }

       func getSut() -> SentryWatchdogTerminationFieldsProcessor {
           SentryWatchdogTerminationFieldsProcessor(
               withDispatchQueueWrapper: dispatchQueueWrapper,
               scopePersistentStore: scopePersistentStore
           )
       }
   }

   private var fixture: Fixture!
   private var sut: SentryWatchdogTerminationFieldsProcessor!

   override func setUpWithError() throws {
       fixture = try Fixture()
       sut = fixture.getSut()
   }

   // MARK: - Context Tests

   func testInit_fileExistsAtActiveFilePath_shouldDeleteFile() throws {
       // -- Arrange --
       createPersistedFile(field: .context)
       assertPersistedFileExists(field: .context)

       // -- Act --
       let _ = fixture.getSut()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }

   func testInit_fileExistsAtContextPath_shouldDeleteFile() throws {
       // -- Arrange --
       assertPersistedFileNotExists(field: .context)

       // -- Act --
       let _ = fixture.getSut()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }

   func testSetContext_whenContextIsValid_shouldDispatchToQueue() {
       // -- Act --
       sut.setContext(fixture.context)

       // -- Assert --
       XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
   }

   func testSetContext_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
       sut.setContext(fixture.context)
       sut = nil

       // Execute the block after the processor is deallocated to have a weak reference
       // in the dispatch block
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

       // -- Assert --
       // This assertion is a best-effort check to see if the block was executed, as there is not other
       // mechanism to assert this case
       XCTAssertTrue(logOutput.loggedMessages.contains { line in
           line.contains("Can not set context, reason: reference to processor is nil")
       })
   }

   func testSetContext_whenContextIsNilAndActiveFileExists_shouldDeleteActiveFile() {
       // -- Arrange --
       createPersistedFile(field: .context)
       assertPersistedFileExists(field: .context)

       // -- Act --
       sut.setContext(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }

   func testSetContext_whenContextIsNilAndActiveFileNotExists_shouldNotThrow() {
       // -- Arrange --
       assertPersistedFileNotExists(field: .context)

       // -- Act --
       sut.setContext(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }

   func testSetContext_whenContextIsInvalidJSON_shouldLogErrorAndNotThrow() {
       // -- Arrange --
       // Define a log mock to assert the execution path
       let logOutput = TestLogOutput()
       SentrySDKLog.setLogOutput(logOutput)
       SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

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

       createPersistedFile(field: .context, data: data)
       assertPersistedFileExists(field: .context)

       // -- Act --
       sut.setContext(fixture.invalidContext)

       // -- Assert --
       let writtenData = try Data(contentsOf: fixture.scopePersistentStore.currentFileURLFor(field: .context))
       XCTAssertEqual(writtenData, data)
   }

   // MARK: - User Tests

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
           line.contains("Can not set user, reason: reference to processor is nil")
       })
   }

   func testSetUser_whenUserIsNilAndActiveFileExists_shouldDeleteActiveFile() {
       // -- Arrange --
       createPersistedFile(field: .user)
       assertPersistedFileExists(field: .user)

       // -- Act --
       sut.setUser(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .user)
   }

   func testSetUser_whenUserIsNilAndActiveFileNotExists_shouldNotThrow() {
       // -- Arrange --
       assertPersistedFileNotExists(field: .user)

       // -- Act --
       sut.setUser(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .user)
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

       createPersistedFile(field: .user, data: data)
       assertPersistedFileExists(field: .user)

       // -- Act --
       sut.setUser(fixture.invalidUser)

       // -- Assert --
       let writtenData = try Data(contentsOf: fixture.scopePersistentStore.currentFileURLFor(field: .user))
       XCTAssertEqual(writtenData, data)
   }

   // MARK: - Clear Tests

   func testClear_whenContextFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .context)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }
   
   func testClear_whenContextFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .context, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .context)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
   }

   func testClear_whenUserFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .user)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .user)
   }
   
   func testClear_whenUserFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .user, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .user)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .user)
   }

   func testClear_whenBothFilesExist_shouldDeleteBothFiles() {
       // -- Arrange --
       let contextData = Data("Context content".utf8)
       let userData = Data("User content".utf8)
       
       createPersistedFile(field: .context, data: contextData)
       createPersistedFile(field: .user, data: userData)
       
       assertPersistedFileExists(field: .context)
       assertPersistedFileExists(field: .user)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
       assertPersistedFileNotExists(field: .user)
   }

   // MARK: - Assertion Helpers

   fileprivate func createPersistedFile(field: SentryScopeField, data: Data = Data(), file: StaticString = #file, line: UInt = #line) {
       FileManager.default.createFile(atPath: fixture.scopePersistentStore.currentFileURLFor(field: field).path, contents: data)
   }

   fileprivate func assertPersistedFileExists(field: SentryScopeField, file: StaticString = #file, line: UInt = #line) {
       XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.scopePersistentStore.currentFileURLFor(field: field).path), file: file, line: line)
   }

   fileprivate func assertPersistedFileNotExists(field: SentryScopeField, file: StaticString = #file, line: UInt = #line) {
       XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.scopePersistentStore.currentFileURLFor(field: field).path), file: file, line: line)
   }
}
