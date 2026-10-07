@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentrySDKLogTests: XCTestCase {
    private var oldDebug: Bool!
    private var oldLevel: SentryLevel!
    private var oldOutput: SentryLogOutput!
    private var timeIntervalSince1970: TimeInterval = 0.0

    override func setUp() {
        super.setUp()
        oldDebug = SentrySDKLog.isDebug
        oldLevel = SentrySDKLog.diagnosticLevel
        oldOutput = SentrySDKLog.getLogOutput()
        
        let currentDateProvider = TestCurrentDateProvider()
        currentDateProvider.advance(by: 0.1234)
        timeIntervalSince1970 = currentDateProvider.date().timeIntervalSince1970
        
        SentrySDKLog.setCurrentDateProvider(currentDateProvider)
        SentrySDKLog.resetWillLogCallCount()
    }

    override func tearDown() {
        super.tearDown()
        SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
        SentrySDKLog.setOutput(oldOutput)
        SentrySDKLog.setCurrentDateProvider(SentryDefaultCurrentDateProvider())
    }
    
    func testDefault_PrintsFatalAndError() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(true, diagnosticLevel: .error)
        
        SentrySDKLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentrySDKLog.log(message: "1", andLevel: SentryLevel.error)
        SentrySDKLog.log(message: "2", andLevel: SentryLevel.warning)
        SentrySDKLog.log(message: "3", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [\(timeIntervalSince1970)] 0", "[Sentry] [error] [\(timeIntervalSince1970)] 1"], logOutput.loggedMessages)
    }
    
    func testDefaultInitOfLogoutPut() {
        SentrySDKLog.log(message: "0", andLevel: SentryLevel.error)
    }
    
    func testConfigureWithoutDebug_PrintsOnlyAlwaysThreshold() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)

        // -- Act --
        SentrySDKLogSupport.configure(false, diagnosticLevel: SentryLevel.none)
        SentrySDKLog.log(message: "fatal", andLevel: SentryLevel.fatal)
        SentrySDKLog.log(message: "error", andLevel: SentryLevel.error)
        SentrySDKLog.log(message: "warning", andLevel: SentryLevel.warning)
        SentrySDKLog.log(message: "info", andLevel: SentryLevel.info)
        SentrySDKLog.log(message: "debug", andLevel: SentryLevel.debug)
        SentrySDKLog.log(message: "none", andLevel: SentryLevel.none)

        // -- Assert --
        XCTAssertEqual(1, logOutput.loggedMessages.count)
        XCTAssertEqual("[Sentry] [fatal] [\(timeIntervalSince1970)] fatal", logOutput.loggedMessages.first)
    }
    
    func testLevelNone_PrintsEverythingExceptNone() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        
        SentrySDKLogSupport.configure(true, diagnosticLevel: SentryLevel.none)
        SentrySDKLog.log(message: "0", andLevel: SentryLevel.fatal)
        SentrySDKLog.log(message: "1", andLevel: SentryLevel.error)
        SentrySDKLog.log(message: "2", andLevel: SentryLevel.warning)
        SentrySDKLog.log(message: "3", andLevel: SentryLevel.info)
        SentrySDKLog.log(message: "4", andLevel: SentryLevel.debug)
        SentrySDKLog.log(message: "5", andLevel: SentryLevel.none)
        
        XCTAssertEqual(["[Sentry] [fatal] [\(timeIntervalSince1970)] 0",
                        "[Sentry] [error] [\(timeIntervalSince1970)] 1",
                        "[Sentry] [warning] [\(timeIntervalSince1970)] 2",
                        "[Sentry] [info] [\(timeIntervalSince1970)] 3",
                        "[Sentry] [debug] [\(timeIntervalSince1970)] 4"], logOutput.loggedMessages)
    }
    
    func testMacroLogsErrorMessage() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(true, diagnosticLevel: SentryLevel.error)
        
        sentryLogErrorWithMacro("error")
        
        XCTAssertEqual(["[Sentry] [error] [\(timeIntervalSince1970)] [SentryLogTestHelper:21] error"], logOutput.loggedMessages)
    }
    
    func testMacroDoesNotEvaluateArgs_WhenNotMessageNotLogged() {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(true, diagnosticLevel: SentryLevel.info)
        
        sentryLogDebugWithMacroArgsNotEvaluated()
        
        XCTAssertTrue(logOutput.loggedMessages.isEmpty)
    }
    
    func testConvenienceLogs_whenDebuggingIsDisabled_shouldNotEvaluateMessages() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(false, diagnosticLevel: .debug)
        var evaluations = 0
        func message() -> String {
            evaluations += 1
            return "Log Message"
        }

        // -- Act --
        SentrySDKLog.debug(message())
        SentrySDKLog.info(message())
        SentrySDKLog.warning(message())
        SentrySDKLog.error(message())

        // -- Assert --
        XCTAssertEqual(evaluations, 0)
        XCTAssertTrue(logOutput.loggedMessages.isEmpty)
    }

    func testConvenienceLogs_whenDiagnosticLevelFiltersMessages_shouldOnlyEvaluateEnabledMessages() {
        let cases: [(SentryLevel, [SentryLevel])] = [
            (.info, [.info, .warning, .error]),
            (.warning, [.warning, .error]),
            (.error, [.error]),
            (.fatal, [])
        ]
        for (diagnosticLevel, expectedLevels) in cases {
            // -- Arrange --
            let logOutput = TestLogOutput()
            SentrySDKLog.setLogOutput(logOutput)
            SentrySDKLogSupport.configure(true, diagnosticLevel: diagnosticLevel)
            var evaluations = 0
            func message() -> String {
                evaluations += 1
                return "Log Message"
            }

            // -- Act --
            SentrySDKLog.debug(message(), file: "Log.swift", line: 1)
            SentrySDKLog.info(message(), file: "Log.swift", line: 1)
            SentrySDKLog.warning(message(), file: "Log.swift", line: 1)
            SentrySDKLog.error(message(), file: "Log.swift", line: 1)

            // -- Assert --
            XCTAssertEqual(evaluations, expectedLevels.count, "Diagnostic level: \(diagnosticLevel)")
            XCTAssertEqual(expectedLevels.map {
                "[Sentry] [\($0)] [\(timeIntervalSince1970)] [Log:1] Log Message"
            }, logOutput.loggedMessages)
        }
    }

    func testConvenienceLogs_whenEnabled_shouldEvaluateMessagesOnceAndPreserveSourceLocation() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
        var evaluations = 0
        func message() -> String {
            evaluations += 1
            return "Log \(evaluations)"
        }

        // -- Act --
        let line = #line + 1
        SentrySDKLog.debug(message())
        SentrySDKLog.info(message())
        SentrySDKLog.warning(message())
        SentrySDKLog.error(message())

        // -- Assert --
        XCTAssertEqual(evaluations, 4)
        XCTAssertEqual([
            "[Sentry] [debug] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line)] Log 1",
            "[Sentry] [info] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line + 1)] Log 2",
            "[Sentry] [warning] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line + 2)] Log 3",
            "[Sentry] [error] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line + 3)] Log 4"
        ], logOutput.loggedMessages)
    }

    func testFatal_whenDebuggingIsDisabled_shouldStillEvaluateAndLogMessage() {
        // -- Arrange --
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLogSupport.configure(false, diagnosticLevel: .none)
        var evaluations = 0
        func message() -> String {
            evaluations += 1
            return "Fatal Log"
        }

        // -- Act --
        let line = #line + 1
        SentrySDKLog.fatal(message())

        // -- Assert --
        XCTAssertEqual(evaluations, 1)
        XCTAssertEqual(["[Sentry] [fatal] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line)] Fatal Log"], logOutput.loggedMessages)
    }

    func testLogMessageAndLevel_whenEnabled_shouldCheckWillLogOncePerLog() {
        // -- Arrange --
        // Configure first: it initializes the async log file, which emits a debug log on first use.
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.resetWillLogCallCount()

        // -- Act --
        SentrySDKLog.log(message: "debug", andLevel: .debug)
        SentrySDKLog.log(message: "info", andLevel: .info)
        SentrySDKLog.log(message: "warning", andLevel: .warning)
        SentrySDKLog.log(message: "error", andLevel: .error)
        SentrySDKLog.log(message: "fatal", andLevel: .fatal)

        // -- Assert --
        XCTAssertEqual(SentrySDKLog.getWillLogCallCount(), 5)
        XCTAssertEqual(logOutput.loggedMessages.count, 5)
    }

    func testLogMessageAndLevel_whenFiltered_shouldCheckWillLogOncePerLog() {
        // -- Arrange --
        SentrySDKLogSupport.configure(false, diagnosticLevel: .none)
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.resetWillLogCallCount()

        // -- Act --
        SentrySDKLog.log(message: "debug", andLevel: .debug)
        SentrySDKLog.log(message: "info", andLevel: .info)
        SentrySDKLog.log(message: "warning", andLevel: .warning)
        SentrySDKLog.log(message: "error", andLevel: .error)
        SentrySDKLog.log(message: "fatal", andLevel: .fatal)

        // -- Assert --
        // Fatal is at the always-log threshold, so it is the only message that gets through.
        XCTAssertEqual(SentrySDKLog.getWillLogCallCount(), 5)
        XCTAssertEqual(logOutput.loggedMessages, ["[Sentry] [fatal] [\(timeIntervalSince1970)] fatal"])
    }

    func testConvenienceLogs_whenEnabled_shouldCheckWillLogOncePerLog() {
        // -- Arrange --
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.resetWillLogCallCount()

        // -- Act --
        SentrySDKLog.debug("debug")
        SentrySDKLog.info("info")
        SentrySDKLog.warning("warning")
        SentrySDKLog.error("error")

        // -- Assert --
        XCTAssertEqual(SentrySDKLog.getWillLogCallCount(), 4)
        XCTAssertEqual(logOutput.loggedMessages.count, 4)
    }

    func testConvenienceLogs_whenFiltered_shouldCheckWillLogOncePerLog() {
        // -- Arrange --
        SentrySDKLogSupport.configure(false, diagnosticLevel: .none)
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.resetWillLogCallCount()

        // -- Act --
        SentrySDKLog.debug("debug")
        SentrySDKLog.info("info")
        SentrySDKLog.warning("warning")
        SentrySDKLog.error("error")

        // -- Assert --
        XCTAssertEqual(SentrySDKLog.getWillLogCallCount(), 4)
        XCTAssertTrue(logOutput.loggedMessages.isEmpty)
    }

    func testFatal_whenCalled_shouldLogWithoutCheckingWillLog() {
        // -- Arrange --
        SentrySDKLogSupport.configure(false, diagnosticLevel: .none)
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.resetWillLogCallCount()

        // -- Act --
        let line = #line + 1
        SentrySDKLog.fatal("fatal")

        // -- Assert --
        // Fatal is always logged, so it skips the level check entirely.
        XCTAssertEqual(SentrySDKLog.getWillLogCallCount(), 0)
        XCTAssertEqual(logOutput.loggedMessages, ["[Sentry] [fatal] [\(timeIntervalSince1970)] [SentrySDKLogTests:\(line)] fatal"])
    }

    /// Verifies that passing nil to setOutput (which can happen from Objective-C callers
    /// despite NS_ASSUME_NONNULL) falls back to the default print handler instead of crashing.
    func testSetOutput_whenNilFromObjC_shouldFallbackToDefaultPrint() {
        // -- Arrange --
        // Simulate what happens when an Objective-C caller passes nil despite nullability annotations.
        // In Swift, we can't directly pass nil to a non-optional parameter, but the Swift method
        // now accepts an optional to handle this case defensively.

        // -- Act --
        // Call setOutput with nil - this should not crash and should reset to default print handler
        SentrySDKLog.setOutput(nil)

        // -- Assert --
        // Logging should work without crashing (uses default print handler)
        // This would crash before the fix if logOutput was actually nil
        SentrySDKLog.log(message: "test message after nil output", andLevel: SentryLevel.error)

        // If we reach here without crashing, the test passes
    }

    /// This test only ensures we're not crashing when calling configure and log from multiple threads.
    func testAccessFromMultipleThreads_DoesNotCrash() {
        let dispatchQueue = DispatchQueue(label: "com.sentry.log.configuration.test", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "SentryLog Configuration and Logging")
        expectation.expectedFulfillmentCount = 1_000

        for _ in 0..<1_000 {
            dispatchQueue.async {
                SentrySDKLog._configure(false, diagnosticLevel: .error)

                for _ in 0..<100 {
                    SentrySDKLog.log(message: "This is a test message", andLevel: SentryLevel.debug)
                    SentrySDKLog.log(message: "This is another test message", andLevel: SentryLevel.info)
                }

                expectation.fulfill()
            }
        }

        dispatchQueue.activate()

        wait(for: [expectation], timeout: 5.0)
    }

}
