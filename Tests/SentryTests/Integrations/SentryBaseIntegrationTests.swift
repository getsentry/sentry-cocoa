import Sentry
import XCTest

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

    func testIsEnabled_True() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.isEnabled(true), true)
        XCTAssertEqual([], logOutput.loggedMessages)
    }

    func testIsEnabled_False() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.isEnabled(false), false)
        XCTAssertEqual(["Sentry - debug:: Not going to enable SentryBaseIntegration"], logOutput.loggedMessages)
    }

    func testShouldBeEnabled_Bools_True() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.shouldBeEnabled([true, true]), true)
        XCTAssertEqual([], logOutput.loggedMessages)
    }

    func testShouldBeEnabled_Bools_False() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.shouldBeEnabled([true, false]), false)
        XCTAssertEqual(["Sentry - debug:: Not going to enable SentryBaseIntegration"], logOutput.loggedMessages)
    }

    func testShouldBeEnabled_SentryOptionWithDescription_True() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.shouldBeEnabled([SentryOptionWithDescription(option: true, log: "Log me")]), true)
        XCTAssertEqual(sut.shouldBeEnabled([SentryOptionWithDescription(option: true, optionName: "optionName")]), true)
        XCTAssertEqual([], logOutput.loggedMessages)
    }

    func testShouldBeEnabled_SentryOptionWithDescription_False() {
        let sut = SentryBaseIntegration()
        XCTAssertEqual(sut.shouldBeEnabled([SentryOptionWithDescription(option: false, log: "Log me")]), false)
        XCTAssertEqual(sut.shouldBeEnabled([SentryOptionWithDescription(option: false, optionName: "optionName")]), false)
        XCTAssertEqual(["Sentry - debug:: Log me", "Sentry - debug:: Not going to enable SentryBaseIntegration because optionName is disabled"], logOutput.loggedMessages)
    }

    class TestLogOutput: SentryLogOutput {
        var loggedMessages: [String] = []
        override func log(_ message: String) {
            loggedMessages.append(message)
        }
    }
}
