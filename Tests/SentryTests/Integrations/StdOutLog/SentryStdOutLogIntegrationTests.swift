@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryStdOutLogIntegrationTests: XCTestCase {

    private class TestLoggerDelegate: NSObject, SentryLoggerDelegate {
        let capturedLogs = Invocations<SentryLog>()
        
        func capture(log: SentryLog) {
            capturedLogs.record(log)
        }
    }

    private class Fixture {
        let options: Options
        let client: TestClient
        let delegate: TestLoggerDelegate
        let logger: SentryLogger
        let testQueue: TestSentryDispatchQueueWrapper
        
        init() {
            options = Options()
            options.enableLogs = true
            
            client = TestClient(options: options)!
            delegate = TestLoggerDelegate()
            logger = SentryLogger(delegate: delegate, dateProvider: TestCurrentDateProvider())
            
            testQueue = TestSentryDispatchQueueWrapper()
            testQueue.dispatchAsyncExecutesBlock = true
        }
        
        func getIntegration() -> SentryStdOutLogIntegration {
            return SentryStdOutLogIntegration(dispatchQueue: testQueue, logger: logger)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInstallWithLogsEnabled() {
        let integration = fixture.getIntegration()
        let installed = integration.install(with: fixture.options)
        
        XCTAssertTrue(installed, "Integration should install when logs are enabled")
        
        // Clean up
        integration.uninstall()
    }

    func testInstallWithLogsDisabled() {
        let options = Options()
        options.enableLogs = false
        
        let integration = fixture.getIntegration()
        let result = integration.install(with: options)
        
        XCTAssertFalse(result, "Integration should not install when logs are disabled")
    }

    func testUninstall() {
        let integration = fixture.getIntegration()
        let installed = integration.install(with: fixture.options)
        XCTAssertTrue(installed, "Integration should install first")
        
        // Uninstall should not crash
        integration.uninstall()
        
        // Test that we can uninstall multiple times without issues
        integration.uninstall()
    }

    func testStdoutCapture() throws {
        let integration = fixture.getIntegration()
        _ = integration.install(with: fixture.options)
                
        print("App stdout message from print")
        expect("Wait for stdout capture to trigger async dispatch")
        
        let log = try XCTUnwrap(fixture.delegate.capturedLogs.first)
        XCTAssertEqual(log.level, SentryLog.Level.info, "Should use info level for stdout")
        XCTAssertTrue(log.body.contains("App stdout message from print"), "Should contain the stdout test message")
        XCTAssertEqual(log.attributes["sentry.log.source"]?.value as? String, "stdout", "Should have stdout source attribute")
        
        // Clean up
        integration.uninstall()
    }

    func testStderrCapture() throws {
        let integration = fixture.getIntegration()
        _ = integration.install(with: fixture.options)
                
        // Use NSLog to write to stderr (this should be captured)
        NSLog("App stderr message from NSLog")
        expect("Wait for stderr capture to trigger async dispatch")
        
        let log = try XCTUnwrap(fixture.delegate.capturedLogs.first)
        XCTAssertEqual(log.level, SentryLog.Level.warn, "Should use warn level for stderr")
        XCTAssertTrue(log.body.contains("App stderr message from NSLog"), "Should contain the stderr test message")
        XCTAssertEqual(log.attributes["sentry.log.source"]?.value as? String, "stderr", "Should have stderr source attribute")
        
        // Clean up
        integration.uninstall()
    }
    
    func testSentryLogsAreIgnored() throws {
        let integration = fixture.getIntegration()
        _ = integration.install(with: fixture.options)
        
        print("[Sentry] This is a Sentry internal print log message")
        expect("Wait")
        
        NSLog("[Sentry] This is a Sentry internal NSLog log message")
        expect("Wait")
        
        // Print another normal log to verify the integration is still working
        print("A normal log")
        expect("Wait for second normal log capture")
        
        // Verify only 1 log was captured (the [Sentry] logs were skipped)
        XCTAssertEqual(fixture.delegate.capturedLogs.count, 1, "Only non-Sentry logs should be captured")
        
        let log = try XCTUnwrap(fixture.delegate.capturedLogs.first)
        XCTAssertTrue(log.body.contains("A normal log"), "Only the normal log should be captured")
        XCTAssertFalse(log.body.contains("[Sentry]"), "Sentry internal log should not be captured")
        
        // Clean up
        integration.uninstall()
    }
    
    // Helper
    
    private func expect(_ description: String) {
        // Record the initial count of async dispatch invocations
        let initialAsyncCount = fixture.testQueue.dispatchAsyncInvocations.count
        
        // Wait for the log handler to be dispatched to its queue
        let expectation = XCTestExpectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            let currentAsyncCount = self.fixture.testQueue.dispatchAsyncInvocations.count
            if currentAsyncCount > initialAsyncCount {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        
        wait(for: [expectation], timeout: 1)
        timer.invalidate()
    }
}
