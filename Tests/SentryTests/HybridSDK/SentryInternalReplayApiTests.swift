@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

class SentryInternalReplayApiTests: XCTestCase {

    private var sut: SentryInternalReplayApi!

    override func setUp() {
        super.setUp()
        let container = SentryDependencyContainer.sharedInstance()
        sut = SentryInternalReplayApi(dependencies: container)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - capture

    func testCapture_beforeStart_shouldReturnFalse() {
        XCTAssertFalse(sut.capture())
    }

    // MARK: - replayId

    func testReplayId_beforeStart_shouldReturnNil() {
        XCTAssertNil(sut.replayId)
    }
}

#endif
