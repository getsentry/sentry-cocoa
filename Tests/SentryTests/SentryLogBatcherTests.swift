@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testDateProvider: TestCurrentDateProvider!
    private var testDelegate: TestLogBatcherDelegate!
    private var testDispatchQueue: TestSentryDispatchQueueWrapper!
    private var scope: Scope!
    
    private func getSut() -> SentryLogBatcher {
        return SentryLogBatcher(
            options: options,
            flushTimeout: 0.1, // Very small timeout for testing
            maxLogCount: 10, // Maximum 10 logs per batch
            maxBufferSizeBytes: 8_000, // byte limit for testing (log with attributes ~390 bytes)
            dateProvider: testDateProvider,
            dispatchQueue: testDispatchQueue,
            delegate: testDelegate
        )
    }
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: Self.self)
        options.enableLogs = true

        testDateProvider = TestCurrentDateProvider()
        testDelegate = TestLogBatcherDelegate()
        testDispatchQueue = TestSentryDispatchQueueWrapper()
        testDispatchQueue.dispatchAsyncExecutesBlock = true // Execute encoding immediately
        
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        testDelegate = nil
        testDispatchQueue = nil
        scope = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddMultipleLogs_BatchesTogether() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1, scope: scope)
        sut.addLog(log2, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
        XCTAssertEqual(capturedLogs[0].body, "Log 1")
        XCTAssertEqual(capturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Buffer Size Tests
    
    func testBufferReachesMaxSize_FlushesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let largeLogBody = String(repeating: "A", count: 8_000) // Larger than 8000 byte limit
        let largeLog = createTestLog(body: largeLogBody)
        
        // -- Act --
        sut.addLog(largeLog, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        XCTAssertEqual(capturedLogs[0].body, largeLogBody)
    }
    
    // MARK: - Max Log Count Tests
    
    func testMaxLogCount_FlushesWhenReached() throws {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        for i in 0..<9 {
            let log = createTestLog(body: "Log \(i + 1)")
            sut.addLog(log, scope: scope)
        }
        
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        
        let log = createTestLog(body: "Log \(10)") // Reached 10 max logs limit
        sut.addLog(log, scope: scope)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "Should have captured exactly \(10) logs")
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_FlushesAfterDelay() throws {
        // -- Arrange --
        let sut = getSut()
        let log = createTestLog()
        
        // -- Act --
        sut.addLog(log, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
    }
    
    func testAddingLogToEmptyBuffer_StartsTimer() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1, scope: scope)
        sut.addLog(log2, scope: scope)
        testDispatchQueue.invokeLastDispatchAfterWorkItem()
        
        // -- Assert --
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.count, 1)
        XCTAssertEqual(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.interval, 0.1)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
     
     // MARK: - Manual Capture Logs Tests
    
    func testManualCaptureLogs_CapturesImmediately() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1, scope: scope)
        sut.addLog(log2, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 2)
    }
    
    func testManualCaptureLogs_CancelsScheduledCapture() throws {
        // -- Arrange --
        let sut = getSut()
        let log = createTestLog()
        sut.addLog(log, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        
        // -- Act --
        sut.captureLogs()
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Manual flush should work and timer should be cancelled")
    }
    
    func testManualCaptureLogs_WithEmptyBuffer_DoesNothing() {
        // -- Arrange --
        let sut = getSut()
        
        // -- Act --
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testScheduledFlushAfterBufferAlreadyFlushed_DoesNothing() throws {
        // -- Arrange --
        let sut = getSut()
        let largeLogBody = String(repeating: "B", count: 4_000)
        let log1 = createTestLog(body: largeLogBody)
        let log2 = createTestLog(body: largeLogBody)
        
        // -- Act --
        sut.addLog(log1, scope: scope)
        let timerWorkItem = try XCTUnwrap(testDispatchQueue.dispatchAfterWorkItemInvocations.first?.workItem)
        sut.addLog(log2, scope: scope)
        timerWorkItem.perform()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1)
    }
    
    func testAddLogAfterFlush_StartsNewBatch() throws {
        // -- Arrange --
        let sut = getSut()
        let log1 = createTestLog(body: "Log 1")
        let log2 = createTestLog(body: "Log 2")
        
        // -- Act --
        sut.addLog(log1, scope: scope)
        sut.captureLogs()
        sut.addLog(log2, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 2)
        
        let allCapturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(allCapturedLogs.count, 2)
        XCTAssertEqual(allCapturedLogs[0].body, "Log 1")
        XCTAssertEqual(allCapturedLogs[1].body, "Log 2")
    }
    
    // MARK: - Integration Tests
    
    func testConcurrentAdds_ThreadSafe() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBatcher(
            options: options,
            flushTimeout: 5,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            delegate: testDelegate
        )
        
        let expectation = XCTestExpectation(description: "Concurrent adds")
        expectation.expectedFulfillmentCount = 10
        
        // -- Act --
        for i in 0..<10 {
            DispatchQueue.global().async {
                let log = self.createTestLog(body: "Log \(i)")
                sutWithRealQueue.addLog(log, scope: self.scope)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        sutWithRealQueue.captureLogs()
        
        // -- Assert --
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 10, "All 10 concurrently added logs should be in the batch")
    }

    func testDispatchAfterTimeoutWithRealDispatchQueue() throws {
        // -- Arrange --
        let sutWithRealQueue = SentryLogBatcher(
            options: options,
            flushTimeout: 0.2,
            maxLogCount: 1_000, // Maximum 1000 logs per batch
            maxBufferSizeBytes: 10_000,
            dateProvider: testDateProvider,
            dispatchQueue: SentryDispatchQueueWrapper(),
            delegate: testDelegate
        )
        
        let log = createTestLog(body: "Real timeout test log")
        let expectation = XCTestExpectation(description: "Real timeout flush")
        
        // -- Act --
        sutWithRealQueue.addLog(log, scope: scope)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 1, "Timeout should trigger flush")
        
        let capturedLogs = self.testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1, "Should contain exactly one log")
        XCTAssertEqual(capturedLogs[0].body, "Real timeout test log")
    }
    
    // MARK: - Attribute Enrichment Tests
    
    func testAddLog_AddsDefaultAttributes() throws {
        // -- Arrange --
        options.environment = "test-environment"
        options.releaseName = "1.0.0"
        let sut = getSut()

        let span = SentryTracer(transactionContext: TransactionContext(name: "Test Transaction", operation: "test-operation"), hub: nil)
        scope.span = span
        let log = createTestLog(body: "Test log message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertEqual(attributes["sentry.environment"]?.value as? String, "test-environment")
        XCTAssertEqual(attributes["sentry.release"]?.value as? String, "1.0.0")
        XCTAssertEqual(attributes["span_id"]?.value as? String, span.spanId.sentrySpanIdString)
    }
    
    func testAddLog_DoesNotAddNilDefaultAttributes() throws {
        // -- Arrange --
        options.releaseName = nil
        let sut = getSut()
        let log = createTestLog(body: "Test log message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["sentry.release"])
        XCTAssertNil(attributes["span_id"])
        XCTAssertEqual(attributes["sentry.sdk.name"]?.value as? String, SentryMeta.sdkName)
        XCTAssertEqual(attributes["sentry.sdk.version"]?.value as? String, SentryMeta.versionString)
        XCTAssertNotNil(attributes["sentry.environment"])
    }
    
    func testAddLog_SetsTraceIdFromPropagationContext() throws {
        // -- Arrange --
        let expectedTraceId = SentryId()
        let propagationContext = SentryPropagationContext(traceId: expectedTraceId, spanId: SpanId())
        scope.propagationContext = propagationContext
        let sut = getSut()
        let log = createTestLog(body: "Test log message with trace ID")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.traceId, expectedTraceId)
    }
    
    func testAddLog_whenSendDefaultPiiTrue_shouldAddUserAttributes() throws {
        // -- Arrange --
        options.sendDefaultPii = true

        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)

        let sut = getSut()
        let log = createTestLog(body: "Test log message with user")

        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()

        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes

        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertEqual(attributes["user.name"]?.value as? String, "test-name")
        XCTAssertEqual(attributes["user.email"]?.value as? String, "test@test.com")
    }

    func testAddLog_whenSendDefaultPiiFalse_shouldNotAddUserAttributes() throws {
        // -- Arrange --
        let installationId = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
        options.sendDefaultPii = false

        let user = User()
        user.userId = "123"
        user.email = "test@test.com"
        user.name = "test-name"
        scope.setUser(user)

        let sut = getSut()
        let log = createTestLog(body: "Test log message with user")

        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()

        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes

        // The installation id is used as a fallback for the user.id
        XCTAssertEqual(attributes["user.id"]?.value as? String, installationId)
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }

    func testAddLog_whenSendDefaultPiiTrue_shouldNotAddNilUserAttributes() throws {
        // -- Arrange --
        options.sendDefaultPii = true

        let user = User()
        user.userId = "123"
        scope.setUser(user)
        
        let sut = getSut()
        let log = createTestLog(body: "Test log message with partial user")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["user.id"]?.value as? String, "123")
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddLog_NoUserAtributesAreSetIfInstallationIdIsNotCached() throws {
        // -- Arrange --
        let sut = getSut()
        let log = createTestLog(body: "Test log message without user")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["user.id"])
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddLog_OnlySetsUserIdToInstallationIdWhenNoUserIsSet() throws {
        // -- Arrange --
        _ = SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath)
        let sut = getSut()
        let log = createTestLog(body: "Test log message without user")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertNotNil(attributes["user.id"])
        XCTAssertEqual(attributes["user.id"]?.value as? String, SentryInstallation.id(withCacheDirectoryPath: options.cacheDirectoryPath))
        XCTAssertNil(attributes["user.name"])
        XCTAssertNil(attributes["user.email"])
    }
    
    func testAddLog_AddsOSAndDeviceAttributes() throws {
        // -- Arrange --
        let osContext = ["name": "iOS", "version": "16.0.1"]
        let deviceContext = ["family": "iOS", "model": "iPhone14,4"]
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        let sut = getSut()
        let log = createTestLog(body: "Test log message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "iOS")
        XCTAssertEqual(attributes["os.version"]?.value as? String, "16.0.1")
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertEqual(attributes["device.model"]?.value as? String, "iPhone14,4")
        XCTAssertEqual(attributes["device.family"]?.value as? String, "iOS")
    }
    
    func testAddLog_HandlesPartialOSAndDeviceAttributes() throws {
        // -- Arrange --
        let osContext = ["name": "macOS"]
        let deviceContext = ["family": "macOS"]
        scope.setContext(value: osContext, key: "os")
        scope.setContext(value: deviceContext, key: "device")
        let sut = getSut()
        let log = createTestLog(body: "Test log message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["os.name"]?.value as? String, "macOS")
        XCTAssertNil(attributes["os.version"])
        XCTAssertEqual(attributes["device.brand"]?.value as? String, "Apple")
        XCTAssertNil(attributes["device.model"])
        XCTAssertEqual(attributes["device.family"]?.value as? String, "macOS")
    }
    
    func testAddLog_HandlesMissingOSAndDeviceContext() throws {
        // -- Arrange --
        scope.removeContext(key: "os")
        scope.removeContext(key: "device")
        let sut = getSut()
        let log = createTestLog(body: "Test log message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertNil(attributes["os.name"])
        XCTAssertNil(attributes["os.version"])
        XCTAssertNil(attributes["device.brand"])
        XCTAssertNil(attributes["device.model"])
        XCTAssertNil(attributes["device.family"])
    }
    
    func testAddLog_AddsScopeAttributes() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setAttribute(value: "aString", key: "string-attribute")
        scope.setAttribute(value: false, key: "bool-attribute")
        scope.setAttribute(value: 1.765, key: "double-attribute")
        scope.setAttribute(value: 5, key: "integer-attribute")
        let sut = getSut()
        let log = createTestLog(body: "Test log message with user")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["string-attribute"]?.value as? String, "aString")
        XCTAssertEqual(attributes["string-attribute"]?.type, "string")
        XCTAssertEqual(attributes["bool-attribute"]?.value as? Bool, false)
        XCTAssertEqual(attributes["bool-attribute"]?.type, "boolean")
        XCTAssertEqual(attributes["double-attribute"]?.value as? Double, 1.765)
        XCTAssertEqual(attributes["double-attribute"]?.type, "double")
        XCTAssertEqual(attributes["integer-attribute"]?.value as? Int, 5)
        XCTAssertEqual(attributes["integer-attribute"]?.type, "integer")
    }
    
    func testAddLog_ScopeAttributesDoNotOverrideLogAttribute() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setAttribute(value: true, key: "log-attribute")
        let sut = getSut()
        let log = createTestLog(body: "Test log message with user", attributes: [ "log-attribute": .init(value: false)])
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["log-attribute"]?.value as? Bool, false)
        XCTAssertEqual(attributes["log-attribute"]?.type, "boolean")
    }
    
    // MARK: - Replay Attributes Tests
    
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
    func testAddLog_ReplayAttributes_SessionMode_AddsReplayId() throws {
        // -- Arrange --
        let replayId = "12345678-1234-1234-1234-123456789012"
        scope.replayId = replayId
        let sut = getSut()
        let log = createTestLog(body: "Test message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.attributes["sentry.replay_id"]?.value as? String, replayId)
        XCTAssertNil(capturedLog.attributes["sentry._internal.replay_is_buffering"])
    }
    
    func testAddLog_ReplayAttributes_NoReplayId_NoAttributesAdded() throws {
        // -- Arrange --
        scope.replayId = nil
        let sut = getSut()
        let log = createTestLog(body: "Test message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertNil(capturedLog.attributes["sentry.replay_id"])
        XCTAssertNil(capturedLog.attributes["sentry._internal.replay_is_buffering"])
    }
#endif
#endif
    
    // MARK: - BeforeSendLog Callback Tests
    
    func testBeforeSendLog_ReturnsModifiedLog() throws {
        // -- Arrange --
        var beforeSendCalled = false
        options.beforeSendLog = { log in
            beforeSendCalled = true
            
            XCTAssertEqual(log.level, .info)
            XCTAssertEqual(log.body, "Original message")
            
            log.body = "Modified by callback"
            log.level = .warn
            log.attributes["callback_modified"] = SentryLog.Attribute(boolean: true)
            
            return log
        }
        let sut = getSut()
        let log = createTestLog(level: .info, body: "Original message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.level, .warn)
        XCTAssertEqual(capturedLog.body, "Modified by callback")
        XCTAssertEqual(capturedLog.attributes["callback_modified"]?.value as? Bool, true)
    }
    
    func testBeforeSendLog_ReturnsNil_LogNotCaptured() {
        // -- Arrange --
        var beforeSendCalled = false
        options.beforeSendLog = { _ in
            beforeSendCalled = true
            return nil // Drop the log
        }
        let sut = getSut()
        let log = createTestLog(body: "This log should be dropped")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertTrue(beforeSendCalled)
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
    }
    
    func testBeforeSendLog_NotSet_LogCapturedUnmodified() throws {
        // -- Arrange --
        options.beforeSendLog = nil
        let sut = getSut()
        let log = createTestLog(level: .debug, body: "Debug message")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 1)
        
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        XCTAssertEqual(capturedLog.level, .debug)
        XCTAssertEqual(capturedLog.body, "Debug message")
    }
    
    func testBeforeSendLog_PreservesOriginalLogAttributes() throws {
        // -- Arrange --
        options.beforeSendLog = { log in
            log.attributes["added_by_callback"] = SentryLog.Attribute(string: "callback_value")
            return log
        }
        let sut = getSut()
        
        let logAttributes: [String: SentryLog.Attribute] = [
            "original_key": SentryLog.Attribute(string: "original_value"),
            "user_id": SentryLog.Attribute(integer: 12_345)
        ]
        let log = createTestLog(body: "Test message", attributes: logAttributes)
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        let capturedLogs = testDelegate.getCapturedLogs()
        let capturedLog = try XCTUnwrap(capturedLogs.first)
        let attributes = capturedLog.attributes
        
        XCTAssertEqual(attributes["original_key"]?.value as? String, "original_value")
        XCTAssertEqual(attributes["user_id"]?.value as? Int, 12_345)
        XCTAssertEqual(attributes["added_by_callback"]?.value as? String, "callback_value")
    }
    
    func testAddLog_WithLogsDisabled_DoesNotCaptureLog() {
        // -- Arrange --
        options.enableLogs = false
        let sut = getSut()
        let log = createTestLog(body: "This log should be ignored")
        
        // -- Act --
        sut.addLog(log, scope: scope)
        sut.captureLogs()
        
        // -- Assert --
        XCTAssertEqual(testDelegate.captureLogsDataInvocations.count, 0)
        let capturedLogs = testDelegate.getCapturedLogs()
        XCTAssertEqual(capturedLogs.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: attributes
        )
    }
}

// MARK: - Test Helpers

final class TestLogBatcherDelegate: NSObject, SentryLogBatcherDelegate {
    var captureLogsDataInvocations = Invocations<(data: Data, count: NSNumber)>()
    
    func capture(logsData: NSData, count: NSNumber) {
        captureLogsDataInvocations.record((logsData as Data, count))
    }
    
    // Helper to get captured logs
    func getCapturedLogs() -> [SentryLog] {
        var allLogs: [SentryLog] = []
        
        for invocation in captureLogsDataInvocations.invocations {
            if let jsonObject = try? JSONSerialization.jsonObject(with: invocation.data) as? [String: Any],
               let items = jsonObject["items"] as? [[String: Any]] {
                for item in items {
                    if let log = parseSentryLog(from: item) {
                        allLogs.append(log)
                    }
                }
            }
        }
        
        return allLogs
    }
    
    private func parseSentryLog(from dict: [String: Any]) -> SentryLog? {
        guard let body = dict["body"] as? String,
              let levelString = dict["level"] as? String,
              let level = try? SentryLog.Level(value: levelString) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: (dict["timestamp"] as? TimeInterval) ?? 0)
        let traceIdString = dict["trace_id"] as? String ?? ""
        let traceId = SentryId(uuidString: traceIdString)
        
        var attributes: [String: SentryLog.Attribute] = [:]
        if let attributesDict = dict["attributes"] as? [String: [String: Any]] {
            for (key, value) in attributesDict {
                if let attrValue = value["value"] {
                    attributes[key] = SentryLog.Attribute(value: attrValue)
                }
            }
        }
        
        return SentryLog(timestamp: timestamp, traceId: traceId, level: level, body: body, attributes: attributes)
    }
}
