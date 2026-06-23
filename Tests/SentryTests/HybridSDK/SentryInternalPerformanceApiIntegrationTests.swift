@testable import Sentry
import SentryTestUtils
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalPerformanceApiIntegrationTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryInternalPerformanceApiIntegrationTests.self)

    override func setUp() {
        super.setUp()
        SentrySDK.start { options in
            options.dsn = SentryInternalPerformanceApiIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    // MARK: - accessor

    func testPerformance_shouldBeAccessible() {
        // -- Act --
        let performance = SentrySDK.internal.performance

        // -- Assert --
        XCTAssertNotNil(performance)
    }

    // MARK: - framesTrackingHybridSDKMode

    func testFramesTrackingHybridSDKMode_defaultIsFalse() {
        // -- Assert --
        XCTAssertFalse(SentrySDK.internal.performance.framesTrackingHybridSDKMode)
    }

    func testFramesTrackingHybridSDKMode_whenSet_shouldUpdateValue() {
        // -- Arrange --
        defer { SentrySDK.internal.performance.framesTrackingHybridSDKMode = false }

        // -- Act --
        SentrySDK.internal.performance.framesTrackingHybridSDKMode = true

        // -- Assert --
        XCTAssertTrue(SentrySDK.internal.performance.framesTrackingHybridSDKMode)
    }

    // MARK: - isFramesTrackingRunning

    func testIsFramesTrackingRunning_defaultIsFalse() {
        // -- Assert --
        XCTAssertFalse(SentrySDK.internal.performance.isFramesTrackingRunning)
    }
}

#endif
