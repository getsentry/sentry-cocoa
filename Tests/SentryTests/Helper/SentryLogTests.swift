@testable import Sentry
import SentryTestUtils
import XCTest

class SentryLogTests: XCTestCase {
    var oldDebug: Bool!
    var oldLevel: SentryLevel!
    var oldOutput: SentryLogOutput!

    override func setUp() {
        super.setUp()
        oldDebug = SentryLog.isDebug
        oldLevel = SentryLog.diagnosticLevel
        oldOutput = SentryLog.getLogOutput()
    }

    override func tearDown() {
        super.tearDown()
        SentryLog.configure(oldDebug, diagnosticLevel: oldLevel)
        SentryLog.setLogOutput(oldOutput)
    }

    func testDefault_PrintsFatalAndError() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .error)
        
        SentryLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(message: "1", andLevel: SentryLevel.error)
        SentryLog.log(message: "2", andLevel: SentryLevel.warning)
        SentryLog.log(message: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] 0", "[Sentry] [error] 1"], logOutput.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        SentryLog.log(message: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsNothing() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        
        SentryLog.configure(false, diagnosticLevel: SentryLevel.none)
        SentryLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(message: "0", andLevel: SentryLevel.error)
        SentryLog.log(message: "0", andLevel: SentryLevel.warning)
        SentryLog.log(message: "0", andLevel: SentryLevel.info)
        SentryLog.log(message: "0", andLevel: SentryLevel.debug)
        SentryLog.log(message: "0", andLevel: SentryLevel.none)
        
        XCTAssertEqual(0, logOutput.loggedMessages.count)
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
        
        XCTAssertEqual(["[Sentry] [fatal] 0",
                        "[Sentry] [error] 1",
                        "[Sentry] [warning] 2",
                        "[Sentry] [info] 3",
                        "[Sentry] [debug] 4"], logOutput.loggedMessages)
    }
    
    func testMacroLogsErrorMessage() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: SentryLevel.error)
        
        sentryLogErrorWithMacro("error")
        
        XCTAssertEqual(["[Sentry] [error] [SentryLogTestHelper:21] error"], logOutput.loggedMessages)
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
        XCTAssertEqual(["[Sentry] [debug] [SentryLogTests:\(line)] Debug Log"], logOutput.loggedMessages)
    }
    
}
