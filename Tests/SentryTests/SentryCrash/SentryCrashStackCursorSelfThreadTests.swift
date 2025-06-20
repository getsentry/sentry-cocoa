@_spi(Private) @testable import Sentry
import XCTest

final class SentryCrashStackCursorSelfThreadTests: XCTestCase {

    func testInitSelfThread_DoesNotUseNonAsyncSafeLogging() throws {
        let oldDebug = SentryLogSwift.isDebug
        let oldLevel = SentryLogSwift.diagnosticLevel
        let oldOutput = SentryLogSwift.getLogOutput()

        defer {
            SentryLogSwift.setLogOutput(oldOutput)
            SentryLogSwiftSupport.configure(oldDebug, diagnosticLevel: oldLevel)
        }

        let logOutput = TestLogOutput()
        SentryLogSwift.setLogOutput(logOutput)
        SentryLogSwiftSupport.configure(true, diagnosticLevel: .debug)

        var cursor = SentryCrashStackCursor()
        sentrycrashsc_initSelfThread(&cursor, 1)

        XCTAssertEqual(logOutput.loggedMessages.count, 0, "sentrycrashsc_initSelfThread can be called when crashing and MUST NOT use non async safe logging. You must use SENTRY_ASYNC_SAFE_LOG instead.")
    }
}
