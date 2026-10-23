@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS)
class SentryHingeObserverTests: XCTestCase {

    // `UIHingeInteraction` only exists on iOS 27.1 and later, and the test runtime does not
    // provide it, so the dynamic interaction creation and the window attachment cannot be
    // exercised deterministically here. These tests cover the availability guard and the
    // parsing of hinge updates, which are the parts that run on every runtime.

    @objc private final class FakeHinge: NSObject {
        @objc let status: Int
        @objc let angle: Double

        init(status: Int, angle: Double) {
            self.status = status
            self.angle = angle
        }
    }

    @objc private final class FakeUpdate: NSObject {
        @objc let hinge: FakeHinge?

        init(hinge: FakeHinge?) {
            self.hinge = hinge
        }
    }

    private final class UpdateWithoutHinge: NSObject {}

    private var notificationCenterWrapper: TestNSNotificationCenterWrapper!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    private var application: TestSentryUIApplication!

    override func setUp() {
        super.setUp()
        notificationCenterWrapper = TestNSNotificationCenterWrapper()
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        application = TestSentryUIApplication()
    }

    private func getSut() -> SentryHingeObserver {
        SentryHingeObserver(
            applicationProvider: { [application] in application },
            notificationCenterWrapper: notificationCenterWrapper,
            dispatchQueueWrapper: dispatchQueueWrapper
        )
    }

    // MARK: - Availability

    func testStart_whenHingeInteractionUnavailable_shouldNotObserveWindows() throws {
        try XCTSkipIf(SentryHingeObserver.isHingeInteractionAvailable, "Runtime provides UIHingeInteraction")

        // -- Arrange --
        let sut = getSut()

        // -- Act --
        sut.start { _ in XCTFail("Handler must not be called") }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
    }

    func testCurrentState_whenNoUpdateWasObserved_shouldBeNil() {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        sut.start { _ in }

        // -- Assert --
        XCTAssertNil(sut.currentState)
    }

    func testStop_whenNotStarted_shouldNotRemoveObservers() {
        // -- Arrange --
        let sut = getSut()
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
    }

    // MARK: - Parsing Updates

    func testHingeState_whenUpdateHasHinge_shouldReturnState() throws {
        // -- Arrange --
        let update = FakeUpdate(hinge: FakeHinge(status: 2, angle: 1.25))

        // -- Act --
        let state = try XCTUnwrap(SentryHingeObserver.hingeState(from: update))

        // -- Assert --
        XCTAssertEqual(state.status, .partiallyOpen)
        XCTAssertEqual(state.angle, 1.25)
    }

    func testHingeState_whenStatusIsUnrecognized_shouldReturnUnknown() throws {
        // -- Arrange --
        let update = FakeUpdate(hinge: FakeHinge(status: 42, angle: 0))

        // -- Act --
        let state = try XCTUnwrap(SentryHingeObserver.hingeState(from: update))

        // -- Assert --
        XCTAssertEqual(state.status, .unknown)
    }

    func testHingeState_whenHingeIsNil_shouldReturnNil() {
        // -- Arrange --
        let update = FakeUpdate(hinge: nil)

        // -- Act --
        let state = SentryHingeObserver.hingeState(from: update)

        // -- Assert --
        XCTAssertNil(state)
    }

    func testHingeState_whenUpdateDoesNotRespondToHinge_shouldReturnNil() {
        // -- Arrange --
        let update = UpdateWithoutHinge()

        // -- Act --
        let state = SentryHingeObserver.hingeState(from: update)

        // -- Assert --
        XCTAssertNil(state)
    }

    func testHingeStatus_rawValues_shouldMatchUIHingeStatus() {
        XCTAssertEqual(SentryHingeStatus.unknown.rawValue, 0)
        XCTAssertEqual(SentryHingeStatus.closed.rawValue, 1)
        XCTAssertEqual(SentryHingeStatus.partiallyOpen.rawValue, 2)
        XCTAssertEqual(SentryHingeStatus.fullyOpen.rawValue, 3)
    }
}
#endif // os(iOS)
