@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalPerformanceApiTests: XCTestCase {

    private var sut: SentryInternalPerformanceApi!

    override func setUp() {
        super.setUp()
        let container = SentryDependencyContainer.sharedInstance()
        sut = SentryInternalPerformanceApi(dependencies: container)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - framesTrackingHybridSDKMode

    func testFramesTrackingHybridSDKMode_defaultIsFalse() {
        XCTAssertFalse(sut.framesTrackingHybridSDKMode)
    }

    func testFramesTrackingHybridSDKMode_whenSet_shouldUpdateValue() {
        // -- Arrange --
        defer { sut.framesTrackingHybridSDKMode = false }

        // -- Act --
        sut.framesTrackingHybridSDKMode = true

        // -- Assert --
        XCTAssertTrue(sut.framesTrackingHybridSDKMode)
    }

    // MARK: - isFramesTrackingRunning

    func testIsFramesTrackingRunning_shouldReturnValue() {
        // -- Act --
        let running = sut.isFramesTrackingRunning

        // -- Assert --
        XCTAssertFalse(running)
    }

    // MARK: - currentScreenFrames

    func testCurrentScreenFrames_shouldReturnScreenFrames() {
        // -- Act --
        let frames = sut.currentScreenFrames

        // -- Assert --
        XCTAssertNotNil(frames)
    }
}

#endif
