@testable import Sentry
import SentryTestUtils
import XCTest

class SentryLogTests: XCTestCase {
    private var oldDebug: Bool!
    private var oldLevel: SentryLevel!
    private var oldOutput: SentryLogOutput!
    private let systemUptime: TimeInterval = 0.1234

    override func setUp() {
        super.setUp()
        oldDebug = SentryLog.isDebug
        oldLevel = SentryLog.diagnosticLevel
        oldOutput = SentryLog.getLogOutput()
        
        let currentDateProvider = TestCurrentDateProvider()
        currentDateProvider.advance(by: systemUptime)
        SentryLog.setCurrentDateProvider(currentDateProvider)
    }

    override func tearDown() {
        super.tearDown()
        SentryLog.configure(oldDebug, diagnosticLevel: oldLevel)
        SentryLog.setLogOutput(oldOutput)
        SentryLog.setCurrentDateProvider(SentryDefaultCurrentDateProvider())
    }

    func testDefault_PrintsFatalAndError() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .error)
        
        SentryLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(message: "1", andLevel: SentryLevel.error)
        SentryLog.log(message: "2", andLevel: SentryLevel.warning)
        SentryLog.log(message: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [uptime:\(systemUptime)] 0", "[Sentry] [error] [uptime:\(systemUptime)] 1"], logOutput.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        SentryLog.log(message: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsOnlyAlwaysThreshold() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)

        // -- Act --
        SentryLog.configure(false, diagnosticLevel: SentryLevel.none)
        SentryLog.log(message: "fatal", andLevel: SentryLevel.fatal)
        SentryLog.log(message: "error", andLevel: SentryLevel.error)
        SentryLog.log(message: "warning", andLevel: SentryLevel.warning)
        SentryLog.log(message: "info", andLevel: SentryLevel.info)
        SentryLog.log(message: "debug", andLevel: SentryLevel.debug)
        SentryLog.log(message: "none", andLevel: SentryLevel.none)

        // -- Assert --
        XCTAssertEqual(1, logOutput.loggedMessages.count)
        XCTAssertEqual("[Sentry] [fatal] [uptime:\(systemUptime)] fatal", logOutput.loggedMessages.first)
    }
    
    func testLevelNone_PrintsEverythingExceptNone() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        
        SentryLog.configure(true, diagnosticLevel: SentryLevel.none)
        SentryLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(message: "1", andLevel: SentryLevel.error)
        SentryLog.log(message: "2", andLevel: SentryLevel.warning)
        SentryLog.log(message: "3", andLevel: SentryLevel.info)
        SentryLog.log(message: "4", andLevel: SentryLevel.debug)
        SentryLog.log(message: "5", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [uptime:\(systemUptime)] 0",
                        "[Sentry] [error] [uptime:\(systemUptime)] 1",
                        "[Sentry] [warning] [uptime:\(systemUptime)] 2",
                        "[Sentry] [info] [uptime:\(systemUptime)] 3",
                        "[Sentry] [debug] [uptime:\(systemUptime)] 4"], logOutput.loggedMessages)
    }
    
    func testMacroLogsErrorMessage() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: SentryLevel.error)
        
        sentryLogErrorWithMacro("error")
        
        XCTAssertEqual(["[Sentry] [error] [uptime:\(systemUptime)] [SentryLogTestHelper:21] error"], logOutput.loggedMessages)
    }
    
    func testMacroDoesNotEvaluateArgs_WhenNotMessageNotLogged() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: SentryLevel.info)
        
        sentryLogDebugWithMacroArgsNotEvaluated()
        
        XCTAssertTrue(logOutput.loggedMessages.isEmpty)
    }
    
    func testConvenientLogFunction() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: SentryLevel.debug)
        let line = #line + 1
        SentryLog.debug("Debug Log")
        XCTAssertEqual(["[Sentry] [debug] [uptime:\(systemUptime)] [SentryLogTests:\(line)] Debug Log"], logOutput.loggedMessages)
    }
    
}
