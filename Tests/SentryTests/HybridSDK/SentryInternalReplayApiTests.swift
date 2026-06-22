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

    // MARK: - addIgnoreClasses

    func testAddIgnoreClasses_beforeStart_shouldNotCrash() {
        sut.addIgnoreClasses([UILabel.self])
    }

    // MARK: - addRedactClasses

    func testAddRedactClasses_beforeStart_shouldNotCrash() {
        sut.addRedactClasses([UILabel.self])
    }

    // MARK: - setIgnoreContainerClass

    func testSetIgnoreContainerClass_beforeStart_shouldNotCrash() {
        sut.setIgnoreContainerClass(UIView.self)
    }

    // MARK: - setRedactContainerClass

    func testSetRedactContainerClass_beforeStart_shouldNotCrash() {
        sut.setRedactContainerClass(UIView.self)
    }

    // MARK: - setTags

    func testSetTags_beforeStart_shouldNotCrash() {
        sut.setTags(["key": "value"])
    }
}

#endif
