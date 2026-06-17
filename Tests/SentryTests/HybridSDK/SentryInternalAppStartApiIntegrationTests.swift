@testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalAppStartApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalAppStartApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalAppStartApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - Accessor

    func testAppStart_shouldBeAccessible() {
        // -- Act --
        let appStart = SentrySDK.internal.appStart

        // -- Assert --
        XCTAssertNotNil(appStart)
    }

    // MARK: - hybridSDKMode

    func testHybridSDKMode_defaultIsFalse() {
        // -- Assert --
        XCTAssertFalse(SentrySDK.internal.appStart.hybridSDKMode)
    }

    func testHybridSDKMode_whenSet_shouldUpdateValue() {
        // -- Act --
        SentrySDK.internal.appStart.hybridSDKMode = true
        defer { SentrySDK.internal.appStart.hybridSDKMode = false }

        // -- Assert --
        XCTAssertTrue(SentrySDK.internal.appStart.hybridSDKMode)
    }

    // MARK: - measurementWithSpans

    func testMeasurementWithSpans_withoutAppStart_shouldReturnNil() {
        // -- Act --
        let result = SentrySDK.internal.appStart.measurementWithSpans

        // -- Assert --
        XCTAssertNil(result)
    }
}
