@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryInternalPerformanceApiTests: XCTestCase {

    private var sut: SentryInternalPerformanceApi { SentrySDK.internal.performance }

    override func setUp() {
        super.setUp()
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryInternalPerformanceApiTests.self)
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - isFramesTrackingRunning

    func testIsFramesTrackingRunning_whenNotStarted_shouldReturnFalse() {
        // -- Act --
        let result = sut.isFramesTrackingRunning

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsFramesTrackingRunning_whenStarted_shouldReturnTrue() {
        // -- Arrange --
        SentryDependencyContainer.sharedInstance().framesTracker.start()

        // -- Act --
        let result = sut.isFramesTrackingRunning

        // -- Assert --
        XCTAssertTrue(result)
    }

    // MARK: - currentScreenFrames

    func testCurrentScreenFrames_shouldReturnFrameCounts() {
        // -- Arrange --
        let tracker = SentryDependencyContainer.sharedInstance().framesTracker
        let displayLink = TestDisplayLinkWrapper()
        tracker.setDisplayLinkWrapper(displayLink)
        tracker.start()
        displayLink.call()

        let slow = 2
        let frozen = 1
        let normal = 100
        displayLink.renderFrames(slow, frozen, normal)

        // -- Act --
        let frames = sut.currentScreenFrames

        // -- Assert --
        XCTAssertEqual(UInt(slow + frozen + normal), frames.total)
        XCTAssertEqual(UInt(frozen), frames.frozen)
        XCTAssertEqual(UInt(slow), frames.slow)
    }

    // MARK: - framesTrackingHybridSDKMode

    func testFramesTrackingHybridSDKMode_whenDefault_shouldBeFalse() {
        // -- Act --
        let result = sut.framesTrackingHybridSDKMode

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testFramesTrackingHybridSDKMode_whenSet_shouldPersist() {
        // -- Act --
        sut.framesTrackingHybridSDKMode = true

        // -- Assert --
        XCTAssertTrue(sut.framesTrackingHybridSDKMode)
    }
}

#endif
