import Sentry
import XCTest

class MyTestIntegration: SentryBaseIntegration {
    override func integrationOptions() -> SentryIntegrationOption {
        return .integrationOptionEnableAutoSessionTracking
    }
}

class SentryBaseIntegrationTests: XCTestCase {
    var logOutput: TestLogOutput!

    override func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: SentryLevel.debug)

        logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
    }

    override func tearDown() {
        super.tearDown()
        // Set back to default
        SentryLog.configure(true, diagnosticLevel: SentryLevel.error)
        SentryLog.setLogOutput(nil)
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
        XCTAssertEqual(["Sentry - debug:: Not going to enable SentryTests.MyTestIntegration because enableAutoSessionTracking is disabled."], logOutput.loggedMessages)
    }

    class TestLogOutput: SentryLogOutput {
        var loggedMessages: [String] = []
        override func log(_ message: String) {
            loggedMessages.append(message)
        }
    }
}
