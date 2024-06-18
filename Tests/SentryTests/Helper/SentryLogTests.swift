import SentryTestUtils
import XCTest

class SentryLogTests: XCTestCase {
    let sink = TestLogOutput()
    lazy var fixture = SentryLog(sinks: [sink])

    func testDefault_PrintsFatalAndError() {
        fixture.configure(true, diagnosticLevel: .error)
        fixture.log(withMessage: "0", andLevel: SentryLevel.fatal)
        fixture.log(withMessage: "1", andLevel: SentryLevel.error)
        fixture.log(withMessage: "2", andLevel: SentryLevel.warning)
        fixture.log(withMessage: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] 0", "[Sentry] [error] 1"], sink.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        fixture.log(withMessage: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsNothing() {
        fixture.configure(false, diagnosticLevel: SentryLevel.none)
        fixture.log(withMessage: "0", andLevel: SentryLevel.fatal)
        fixture.log(withMessage: "0", andLevel: SentryLevel.error)
        fixture.log(withMessage: "0", andLevel: SentryLevel.warning)
        fixture.log(withMessage: "0", andLevel: SentryLevel.info)
        fixture.log(withMessage: "0", andLevel: SentryLevel.debug)
        fixture.log(withMessage: "0", andLevel: SentryLevel.none)
        
        XCTAssertEqual(0, sink.loggedMessages.count)
    }
    
    func testLevelNone_PrintsEverythingExceptNone() {
        fixture.configure(true, diagnosticLevel: SentryLevel.none)
        fixture.log(withMessage: "0", andLevel: SentryLevel.fatal)
        fixture.log(withMessage: "1", andLevel: SentryLevel.error)
        fixture.log(withMessage: "2", andLevel: SentryLevel.warning)
        fixture.log(withMessage: "3", andLevel: SentryLevel.info)
        fixture.log(withMessage: "4", andLevel: SentryLevel.debug)
        fixture.log(withMessage: "5", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] 0",
                        "[Sentry] [error] 1",
                        "[Sentry] [warning] 2",
                        "[Sentry] [info] 3",
                        "[Sentry] [debug] 4"], sink.loggedMessages)
    }
    
    func testMacroLogsErrorMessage() {
        fixture.configure(true, diagnosticLevel: SentryLevel.error)
        
        sentryLogErrorWithMacro("error", fixture)
        
        XCTAssertEqual(["[Sentry] [error] [SentryLogTestHelper:21] error"], sink.loggedMessages)
    }
    
    func testMacroDoesNotEvaluateArgs_WhenNotMessageNotLogged() {
        fixture.configure(true, diagnosticLevel: SentryLevel.info)
        
        sentryLogDebugWithMacroArgsNotEvaluated(fixture)
        
        XCTAssertTrue(sink.loggedMessages.isEmpty)
    }
}
