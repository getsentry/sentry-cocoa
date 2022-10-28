import Sentry
import XCTest

class MyTestIntegration: SentryBaseIntegration {
    override func integrationOptions() -> SentryIntegrationOption {
        return .integrationOptionEnableAutoSessionTracking
    }
}

class SentryBaseIntegrationTests: XCTestCase {
    var logOutput: TestLogOutput!
    var oldDebug: Bool!
    var oldLevel: SentryLevel!
    var oldOutput: SentryLogOutput!

    override func setUp() {
        super.setUp()
        oldDebug = SentryLog.isDebug()
        oldLevel = SentryLog.diagnosticLevel()
        oldOutput = SentryLog.logOutput()
        SentryLog.configure(true, diagnosticLevel: SentryLevel.debug)
        logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
    }

    override func tearDown() {
        super.tearDown()
        SentryLog.configure(oldDebug, diagnosticLevel: oldLevel)
        SentryLog.setLogOutput(oldOutput)
    }

    func testIntegrationName() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.integrationName(), "SentryBaseIntegration")
    }

    func testInstall() {
        let sut = SentryBaseIntegration()
        let result = sut.install(with: .init())
        XCTAssertTrue(result)
    }

    func testInstall_FailingIntegrationOption() {
        let sut = MyTestIntegration()
        let options = Options()
        options.enableAutoSessionTracking = false
        let result = sut.install(with: options)
        XCTAssertFalse(result)
        XCTAssertFalse(logOutput.loggedMessages.filter({ $0.contains("Not going to enable SentryTests.MyTestIntegration because enableAutoSessionTracking is disabled.") }).isEmpty)
    }
}
