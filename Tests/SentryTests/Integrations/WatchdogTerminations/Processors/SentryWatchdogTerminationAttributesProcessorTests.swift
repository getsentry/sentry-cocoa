@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationAttributesProcessorTests: XCTestCase {
   private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationAttributesProcessorTests.self)

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

       let level: NSNumber = NSNumber(value: SentryLevel.fatal.rawValue)
       let invalidLevel: NSNumber = NSNumber(value: 999) // Invalid level value
       
       let extras: [String: Any] = [
           "extra_key": "extra_value",
           "numeric_key": 42,
           "bool_key": true,
           "array_key": ["item1", "item2"]
       ]
       let invalidExtras: [String: Any] = [
           "invalid_key": Double.infinity
       ]
       
       let fingerprint: [String] = ["fingerprint1", "fingerprint2", "fingerprint3"]

       init() throws {
           let options = Options()
           options.dsn = SentryWatchdogTerminationAttributesProcessorTests.dsn

           self.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
           self.fileManager = try TestFileManager(options: Options())
           self.scopePersistentStore = TestSentryScopePersistentStore(fileManager: fileManager)
       }

       func getSut() -> SentryWatchdogTerminationAttributesProcessor {
           SentryWatchdogTerminationAttributesProcessor(
               withDispatchQueueWrapper: dispatchQueueWrapper,
               scopePersistentStore: scopePersistentStore
           )
       }
   }

   private var fixture: Fixture!
   private var sut: SentryWatchdogTerminationAttributesProcessor!

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

   // MARK: - Level Tests

   func testSetLevel_whenLevelIsValid_shouldDispatchToQueue() {
       // -- Act --
       sut.setLevel(fixture.level)

       // -- Assert --
       XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
   }

   func testSetLevel_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
       sut.setLevel(fixture.level)
       sut = nil

       // Execute the block after the processor is deallocated to have a weak reference
       // in the dispatch block
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

       // -- Assert --
       // This assertion is a best-effort check to see if the block was executed, as there is not other
       // mechanism to assert this case
       XCTAssertTrue(logOutput.loggedMessages.contains { line in
           line.contains("Can not set level, reason: reference to processor is nil")
       })
   }

   func testSetLevel_whenLevelIsNilAndActiveFileExists_shouldDeleteActiveFile() {
       // -- Arrange --
       createPersistedFile(field: .level)
       assertPersistedFileExists(field: .level)

       // -- Act --
       sut.setLevel(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .level)
   }

   func testSetLevel_whenLevelIsNilAndActiveFileNotExists_shouldNotThrow() {
       // -- Arrange --
       assertPersistedFileNotExists(field: .level)

       // -- Act --
       sut.setLevel(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .level)
   }

   func testSetLevel_whenLevelIsValid_shouldWriteToDisk() {
       // -- Act --
       sut.setLevel(fixture.level)

       // -- Assert --
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()
       assertPersistedFileExists(field: .level)
   }

   // MARK: - Extras Tests

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
       SentrySDKLog.setLogOutput(logOutput)
       SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

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
           line.contains("Can not set extras, reason: reference to processor is nil")
       })
   }

   func testSetExtras_whenExtrasIsNilAndActiveFileExists_shouldDeleteActiveFile() {
       // -- Arrange --
       createPersistedFile(field: .extras)
       assertPersistedFileExists(field: .extras)

       // -- Act --
       sut.setExtras(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .extras)
   }

   func testSetExtras_whenExtrasIsNilAndActiveFileNotExists_shouldNotThrow() {
       // -- Arrange --
       assertPersistedFileNotExists(field: .extras)

       // -- Act --
       sut.setExtras(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .extras)
   }

   func testSetExtras_whenExtrasIsInvalidJSON_shouldLogErrorAndNotThrow() {
       // -- Arrange --
       // Define a log mock to assert the execution path
       let logOutput = TestLogOutput()
       SentrySDKLog.setLogOutput(logOutput)
       SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

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

       createPersistedFile(field: .extras, data: data)
       assertPersistedFileExists(field: .extras)

       // -- Act --
       sut.setExtras(fixture.invalidExtras)

       // -- Assert --
       let writtenData = try Data(contentsOf: fixture.scopePersistentStore.currentFileURLFor(field: .extras))
       XCTAssertEqual(writtenData, data)
   }

   func testSetExtras_whenExtrasIsValid_shouldWriteToDisk() {
       // -- Act --
       sut.setExtras(fixture.extras)

       // -- Assert --
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()
       assertPersistedFileExists(field: .extras)
   }

   // MARK: - Fingerprint Tests

   func testSetFingerprint_whenFingerprintIsValid_shouldDispatchToQueue() {
       // -- Act --
       sut.setFingerprint(fixture.fingerprint)

       // -- Assert --
       XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
   }

   func testSetFingerprint_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
       sut.setFingerprint(fixture.fingerprint)
       sut = nil

       // Execute the block after the processor is deallocated to have a weak reference
       // in the dispatch block
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

       // -- Assert --
       // This assertion is a best-effort check to see if the block was executed, as there is not other
       // mechanism to assert this case
       XCTAssertTrue(logOutput.loggedMessages.contains { line in
           line.contains("Can not set fingerprint, reason: reference to processor is nil")
       })
   }

   func testSetFingerprint_whenFingerprintIsNilAndActiveFileExists_shouldDeleteActiveFile() {
       // -- Arrange --
       createPersistedFile(field: .fingerprint)
       assertPersistedFileExists(field: .fingerprint)

       // -- Act --
       sut.setFingerprint(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .fingerprint)
   }

   func testSetFingerprint_whenFingerprintIsNilAndActiveFileNotExists_shouldNotThrow() {
       // -- Arrange --
       assertPersistedFileNotExists(field: .fingerprint)

       // -- Act --
       sut.setFingerprint(nil)

       // -- Assert --
       assertPersistedFileNotExists(field: .fingerprint)
   }

   func testSetFingerprint_whenFingerprintIsValid_shouldWriteToDisk() {
       // -- Act --
       sut.setFingerprint(fixture.fingerprint)

       // -- Assert --
       fixture.dispatchQueueWrapper.invokeLastDispatchAsync()
       assertPersistedFileExists(field: .fingerprint)
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

   func testClear_whenLevelFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .level)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .level)
   }
   
   func testClear_whenLevelFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .level, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .level)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .level)
   }

   func testClear_whenExtrasFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .extras)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .extras)
   }
   
   func testClear_whenExtrasFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .extras, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .extras)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .extras)
   }

   func testClear_whenFingerprintFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .fingerprint)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .fingerprint)
   }
   
   func testClear_whenFingerprintFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .fingerprint, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .fingerprint)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .fingerprint)
   }

   func testClear_whenAllFilesExist_shouldDeleteAllFiles() {
       // -- Arrange --
       let contextData = Data("Context content".utf8)
       let userData = Data("User content".utf8)
       let levelData = Data("Level content".utf8)
       let extrasData = Data("Extras content".utf8)
       let fingerprintData = Data("Fingerprint content".utf8)
       
       createPersistedFile(field: .context, data: contextData)
       createPersistedFile(field: .user, data: userData)
       createPersistedFile(field: .level, data: levelData)
       createPersistedFile(field: .extras, data: extrasData)
       createPersistedFile(field: .fingerprint, data: fingerprintData)
       
       assertPersistedFileExists(field: .context)
       assertPersistedFileExists(field: .user)
       assertPersistedFileExists(field: .level)
       assertPersistedFileExists(field: .extras)
       assertPersistedFileExists(field: .fingerprint)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
       assertPersistedFileNotExists(field: .user)
       assertPersistedFileNotExists(field: .level)
       assertPersistedFileNotExists(field: .extras)
       assertPersistedFileNotExists(field: .fingerprint)
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
