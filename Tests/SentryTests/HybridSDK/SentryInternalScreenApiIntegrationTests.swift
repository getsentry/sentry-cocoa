@testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalScreenApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalScreenApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalScreenApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testScreen_shouldBeAccessible() {
        // -- Act --
        let screen = SentrySDK.internal.screen

        // -- Assert --
        XCTAssertNotNil(screen)
    }

    // MARK: - setCurrent

    func testSetCurrent_shouldSetScreenNameOnScope() {
        // -- Act --
        SentrySDK.internal.screen.setCurrent("TestScreen")

        // -- Assert --
        let scope = SentrySDKInternal.currentHub().scope
        XCTAssertEqual(scope.currentScreen, "TestScreen")
    }

    func testSetCurrent_withNil_shouldClearScreenNameOnScope() {
        // -- Arrange --
        SentrySDK.internal.screen.setCurrent("TestScreen")

        // -- Act --
        SentrySDK.internal.screen.setCurrent(nil)

        // -- Assert --
        let scope = SentrySDKInternal.currentHub().scope
        XCTAssertNil(scope.currentScreen)
    }
}

#endif
