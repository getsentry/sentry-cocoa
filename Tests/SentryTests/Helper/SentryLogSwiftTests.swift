@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryLogSwiftTests: XCTestCase {
    private var oldDebug: Bool!
    private var oldLevel: SentryLevel!
    private var oldOutput: SentryLogOutput!
    private var timeIntervalSince1970: TimeInterval = 0.0

    override func setUp() {
        super.setUp()
        oldDebug = SentryLogSwift.isDebug
        oldLevel = SentryLogSwift.diagnosticLevel
        oldOutput = SentryLogSwift.getLogOutput()
        
        let currentDateProvider = TestCurrentDateProvider()
        currentDateProvider.advance(by: 0.1234)
        timeIntervalSince1970 = currentDateProvider.date().timeIntervalSince1970
        
        SentryLogSwift.setCurrentDateProvider(currentDateProvider)
    }

    override func tearDown() {
        super.tearDown()
        SentryLogSwiftSupport.configure(oldDebug, diagnosticLevel: oldLevel)
        SentryLogSwift.setLogOutput(oldOutput)
        SentryLogSwift.setCurrentDateProvider(SentryDefaultCurrentDateProvider())
    }

    func testDefault_PrintsFatalAndError() {
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        SentryLogSwiftSupport.configure(true, diagnosticLevel: .error)
        
        SentryLogSwift.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLogSwift.log(message: "1", andLevel: SentryLevel.error)
        SentryLogSwift.log(message: "2", andLevel: SentryLevel.warning)
        SentryLogSwift.log(message: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [timeIntervalSince1970:\(timeIntervalSince1970)] 0", "[Sentry] [error] [timeIntervalSince1970:\(timeIntervalSince1970)] 1"], logOutput.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        SentryLogSwift.log(message: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsOnlyAlwaysThreshold() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)

        // -- Act --
        SentryLogSwiftSupport.configure(false, diagnosticLevel: SentryLevel.none)
        SentryLogSwift.log(message: "fatal", andLevel: SentryLevel.fatal)
        SentryLogSwift.log(message: "error", andLevel: SentryLevel.error)
        SentryLogSwift.log(message: "warning", andLevel: SentryLevel.warning)
        SentryLogSwift.log(message: "info", andLevel: SentryLevel.info)
        SentryLogSwift.log(message: "debug", andLevel: SentryLevel.debug)
        SentryLogSwift.log(message: "none", andLevel: SentryLevel.none)

        // -- Assert --
        XCTAssertEqual(1, logOutput.loggedMessages.count)
        XCTAssertEqual("[Sentry] [fatal] [timeIntervalSince1970:\(timeIntervalSince1970)] fatal", logOutput.loggedMessages.first)
    }
    
    func testLevelNone_PrintsEverythingExceptNone() {
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        
        SentryLogSwiftSupport.configure(true, diagnosticLevel: SentryLevel.none)
        SentryLogSwift.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLogSwift.log(message: "1", andLevel: SentryLevel.error)
        SentryLogSwift.log(message: "2", andLevel: SentryLevel.warning)
        SentryLogSwift.log(message: "3", andLevel: SentryLevel.info)
        SentryLogSwift.log(message: "4", andLevel: SentryLevel.debug)
        SentryLogSwift.log(message: "5", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [timeIntervalSince1970:\(timeIntervalSince1970)] 0",
                        "[Sentry] [error] [timeIntervalSince1970:\(timeIntervalSince1970)] 1",
                        "[Sentry] [warning] [timeIntervalSince1970:\(timeIntervalSince1970)] 2",
                        "[Sentry] [info] [timeIntervalSince1970:\(timeIntervalSince1970)] 3",
                        "[Sentry] [debug] [timeIntervalSince1970:\(timeIntervalSince1970)] 4"], logOutput.loggedMessages)
    }
    
    func testMacroLogsErrorMessage() {
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        SentryLogSwiftSupport.configure(true, diagnosticLevel: SentryLevel.error)
        
        sentryLogErrorWithMacro("error")
        
        XCTAssertEqual(["[Sentry] [error] [timeIntervalSince1970:\(timeIntervalSince1970)] [SentryLogTestHelper:20] error"], logOutput.loggedMessages)
    }
    
    func testMacroDoesNotEvaluateArgs_WhenNotMessageNotLogged() {
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        SentryLogSwiftSupport.configure(true, diagnosticLevel: SentryLevel.info)
        
        sentryLogDebugWithMacroArgsNotEvaluated()
        
        XCTAssertTrue(logOutput.loggedMessages.isEmpty)
    }
    
    func testConvenientLogFunction() {
        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        SentryLogSwiftSupport.configure(true, diagnosticLevel: SentryLevel.debug)
        let line = #line + 1
        SentryLogSwift.debug("Debug Log")
        XCTAssertEqual(["[Sentry] [debug] [timeIntervalSince1970:\(timeIntervalSince1970)] [SentryLogTests:\(line)] Debug Log"], logOutput.loggedMessages)
    }

    /// This test only ensures we're not crashing when calling configure and log from multiple threads.
    func testAccessFromMultipleThreads_DoesNotCrash() {
        let dispatchQueue = DispatchQueue(label: "com.sentry.log.configuration.test", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "SentryLog Configuration and Logging")
        expectation.expectedFulfillmentCount = 1_000

        for _ in 0..<1_000 {
            dispatchQueue.async {
                SentryLogSwift._configure(false, diagnosticLevel: .error)

                for _ in 0..<100 {
                    SentryLogSwift.log(message: "This is a test message", andLevel: SentryLevel.debug)
                    SentryLogSwift.log(message: "This is another test message", andLevel: SentryLevel.info)
                }

                expectation.fulfill()
            }
        }

        dispatchQueue.activate()

        wait(for: [expectation], timeout: 5.0)
    }

}
