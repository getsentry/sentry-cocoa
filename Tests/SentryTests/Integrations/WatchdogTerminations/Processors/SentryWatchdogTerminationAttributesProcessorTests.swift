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
       
       let dist: String = "1.0.0"
       
       let env: String = "test"

       let tags: [String: String] = [
           "tag1": "value1",
           "tag2": "value2",
           "environment": "test"
       ]
       
       let traceContext: [String: Any] = [
           "trace_id": "771a43a4192642f0b136d5159a501700",
           "span_id": "6c0f0fea4c4c4c4c",
           "sampled": "true",
           "transaction": "test-transaction"
       ]
       
       let invalidTraceContext: [String: Any] = [
           "trace_id": "771a43a4192642f0b136d5159a501700",
           "span_id": "6c0f0fea4c4c4c4c",
           "invalid_key": Double.infinity
       ]

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
    
    // MARK: - Dist Tests

    func testSetDist_whenDistIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setDist(fixture.dist)

        // -- Assert --
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testSetDist_whenProcessorIsDeallocatedWhileDispatching_shouldNotCauseRetainCycle() {
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
        sut.setDist(fixture.dist)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set dist, reason: reference to processor is nil")
        })
    }

    func testSetDist_whenDistIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile(field: .dist)
        assertPersistedFileExists(field: .dist)

        // -- Act --
        sut.setDist(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .dist)
    }

    func testSetDist_whenDistIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists(field: .dist)

        // -- Act --
        sut.setDist(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .dist)
    }
    
    // MARK: - Environment Tests

    func testSetEnvironment_whenEnvironmentIsValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setEnvironment(fixture.env)

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
        sut.setEnvironment(fixture.env)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set environment, reason: reference to processor is nil")
        })
    }

    func testSetEnvironment_whenEnvironmentIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile(field: .environment)
        assertPersistedFileExists(field: .environment)

        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .environment)
    }

    func testSetEnvironment_whenEnvironmentIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists(field: .environment)

        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .environment)
    }

    // MARK: - Tags Tests

    func testSetTags_whenTagsAreValid_shouldDispatchToQueue() {
        // -- Act --
        sut.setTags(fixture.tags)

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
        sut.setTags(fixture.tags)
        sut = nil

        // Execute the block after the processor is deallocated to have a weak reference
        // in the dispatch block
        fixture.dispatchQueueWrapper.invokeLastDispatchAsync()

        // -- Assert --
        // This assertion is a best-effort check to see if the block was executed, as there is not other
        // mechanism to assert this case
        XCTAssertTrue(logOutput.loggedMessages.contains { line in
            line.contains("Can not set tags, reason: reference to processor is nil")
        })
    }

    func testSetTags_whenTagsAreNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile(field: .tags)
        assertPersistedFileExists(field: .tags)

        // -- Act --
        sut.setTags(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .tags)
    }

    func testSetTags_whenTagsAreNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists(field: .tags)

        // -- Act --
        sut.setTags(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .tags)
    }
    
    // MARK: - Trace Context Tests

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
            line.contains("Can not set trace_context, reason: reference to processor is nil")
        })
    }

    func testSetTraceContext_whenTraceContextIsNilAndActiveFileExists_shouldDeleteActiveFile() {
        // -- Arrange --
        createPersistedFile(field: .traceContext)
        assertPersistedFileExists(field: .traceContext)

        // -- Act --
        sut.setTraceContext(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .traceContext)
    }

    func testSetTraceContext_whenTraceContextIsNilAndActiveFileNotExists_shouldNotThrow() {
        // -- Arrange --
        assertPersistedFileNotExists(field: .traceContext)

        // -- Act --
        sut.setTraceContext(nil)

        // -- Assert --
        assertPersistedFileNotExists(field: .traceContext)
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

        createPersistedFile(field: .traceContext, data: data)
        assertPersistedFileExists(field: .traceContext)

        // -- Act --
        sut.setTraceContext(fixture.invalidTraceContext)

        // -- Assert --
        let writtenData = try Data(contentsOf: fixture.scopePersistentStore.currentFileURLFor(field: .traceContext))
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

   func testClear_whenTagsFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .tags)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .tags)
   }
   
   func testClear_whenTagsFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .tags, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .tags)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .tags)
   }

   func testClear_whenTraceContextFileExistsNot_shouldNotThrow() {
       // -- Arrange --
       // Assert the preconditions
       assertPersistedFileNotExists(field: .traceContext)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .traceContext)
   }
   
   func testClear_whenTraceContextFileExists_shouldDeleteFileWithoutError() {
       // -- Arrange --
       let data = Data("Old content".utf8)
       createPersistedFile(field: .traceContext, data: data)
       // Assert the preconditions
       assertPersistedFileExists(field: .traceContext)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .traceContext)
   }

   func testClear_whenAllFilesExist_shouldDeleteAllFiles() {
       // -- Arrange --
       let contextData = Data("Context content".utf8)
       let userData = Data("User content".utf8)
       let distData = Data("Dist content".utf8)
       let envData = Data("Environment content".utf8)
       let tagsData = Data("Tags content".utf8)
       let traceContextData = Data("Trace Context content".utf8)
       
       createPersistedFile(field: .context, data: contextData)
       createPersistedFile(field: .user, data: userData)
       createPersistedFile(field: .dist, data: distData)
       createPersistedFile(field: .environment, data: envData)
       createPersistedFile(field: .tags, data: tagsData)
       createPersistedFile(field: .traceContext, data: traceContextData)

       assertPersistedFileExists(field: .context)
       assertPersistedFileExists(field: .user)
       assertPersistedFileExists(field: .dist)
       assertPersistedFileExists(field: .environment)
       assertPersistedFileExists(field: .tags)
       assertPersistedFileExists(field: .traceContext)

       // -- Act --
       sut.clear()

       // -- Assert --
       assertPersistedFileNotExists(field: .context)
       assertPersistedFileNotExists(field: .user)
       assertPersistedFileNotExists(field: .dist)
       assertPersistedFileNotExists(field: .environment)
       assertPersistedFileNotExists(field: .tags)
       assertPersistedFileNotExists(field: .traceContext)
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
