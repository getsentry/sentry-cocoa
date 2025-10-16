@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryStdOutLogIntegrationTests: XCTestCase {

    private class Fixture {
        let options: Options
        let client: TestClient
        let hub: SentryHub
        let batcher: TestLogBatcher
        let logger: SentryLogger
        let dispatchFactory: TestDispatchFactory
        
        var testQueue: TestSentryDispatchQueueWrapper?
        
        init() {
            options = Options()
            options.enableLogs = true
            
            client = TestClient(options: options)!
            hub = TestHub(client: client, andScope: Scope())
            batcher = TestLogBatcher(client: client, dispatchQueue: TestSentryDispatchQueueWrapper())
            logger = SentryLogger(hub: hub, dateProvider: TestCurrentDateProvider(), batcher: batcher)
            
            dispatchFactory = TestDispatchFactory()
            dispatchFactory.vendedUtilityQueueHandler = { [weak self] queue in
                self?.testQueue = queue
            }
        }
        
        func getIntegration() -> SentryStdOutLogIntegration {
            return SentryStdOutLogIntegration(dispatchFactory: dispatchFactory, logger: logger)
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
        
        let log = try XCTUnwrap(fixture.batcher.addInvocations.first)
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
        
        let log = try XCTUnwrap(fixture.batcher.addInvocations.first)
        XCTAssertEqual(log.level, SentryLog.Level.warn, "Should use warn level for stderr")
        XCTAssertTrue(log.body.contains("App stderr message from NSLog"), "Should contain the stderr test message")
        XCTAssertEqual(log.attributes["sentry.log.source"]?.value as? String, "stderr", "Should have stderr source attribute")
        
        // Clean up
        integration.uninstall()
    }
    
    // Helper
    
    private func expect(_ description: String, timeout: TimeInterval = 0.1) {
        // Record the initial count of async invocations
        let initialAsyncCount = fixture.testQueue?.dispatchAsyncInvocations.count ?? 0
        
        // Wait for the capture to trigger an async dispatch
        let expectation = XCTestExpectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if (self.fixture.testQueue?.dispatchAsyncInvocations.count ?? 0) > initialAsyncCount {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
}
