import XCTest

class SentryLogTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        // Set back to default
        SentryLog.configure(true, diagnosticLevel: SentryLevel.error)
        SentryLog.setLogOutput(nil)
    }

    func testDefault_PrintsFatalAndError() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(withMessage: "1", andLevel: SentryLevel.error)
        SentryLog.log(withMessage: "2", andLevel: SentryLevel.warning)
        SentryLog.log(withMessage: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["Sentry - fatal:: 0", "Sentry - error:: 1"], logOutput.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsNothing() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        
        SentryLog.configure(false, diagnosticLevel: SentryLevel.none)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.error)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.warning)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.info)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.debug)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.none)
        
        XCTAssertEqual(0, logOutput.loggedMessages.count)
    }
    
    func testLevelNone_PrintsEverythingExceptNone() {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        
        SentryLog.configure(true, diagnosticLevel: SentryLevel.none)
        SentryLog.log(withMessage: "0", andLevel: SentryLevel.fatal)
        SentryLog.log(withMessage: "1", andLevel: SentryLevel.error)
        SentryLog.log(withMessage: "2", andLevel: SentryLevel.warning)
        SentryLog.log(withMessage: "3", andLevel: SentryLevel.info)
        SentryLog.log(withMessage: "4", andLevel: SentryLevel.debug)
        SentryLog.log(withMessage: "5", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["Sentry - fatal:: 0",
                        "Sentry - error:: 1",
                        "Sentry - warning:: 2",
                        "Sentry - info:: 3",
                        "Sentry - debug:: 4"], logOutput.loggedMessages)
    }
    
    class TestLogOutput: SentryLogOutput {
        
        var loggedMessages: [String] = []
        override func log(_ message: String) {
            loggedMessages.append(message)
        }
    }

}
