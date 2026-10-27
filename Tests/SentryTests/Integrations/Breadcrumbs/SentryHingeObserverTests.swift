@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS)
class SentryHingeObserverTests: XCTestCase {

    private final class TestInteraction: NSObject, UIInteraction {
        weak var view: UIView?
        let updateHandler: (SentryHingeState?) -> Void

        init(updateHandler: @escaping (SentryHingeState?) -> Void) {
            self.updateHandler = updateHandler
        }

        func willMove(to view: UIView?) {}

        func didMove(to view: UIView?) {
            self.view = view
        }
    }

    private final class TestInteractionShim: SentryHingeInteractionShim {
        var isAvailable = true
        var returnsInteraction = true
        /// Weak, so only the observer and the windows keep the interactions alive.
        private let createdInteractions = NSHashTable<TestInteraction>.weakObjects()
        var interactions: [TestInteraction] { createdInteractions.allObjects }

        func makeInteraction(updateHandler: @escaping (SentryHingeState?) -> Void) -> UIInteraction? {
            guard returnsInteraction else {
                return nil
            }
            let interaction = TestInteraction(updateHandler: updateHandler)
            createdInteractions.add(interaction)
            return interaction
        }

        func simulateUpdate(_ hingeState: SentryHingeState?) {
            for interaction in interactions {
                interaction.updateHandler(hingeState)
            }
        }
    }

    private var notificationCenterWrapper: TestNSNotificationCenterWrapper!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    private var application: TestSentryUIApplication!
    private var interactionShim: TestInteractionShim!

    override func setUp() {
        super.setUp()
        notificationCenterWrapper = TestNSNotificationCenterWrapper()
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        application = TestSentryUIApplication()
        interactionShim = TestInteractionShim()
    }

    private func getSut() -> SentryHingeObserver {
        SentryHingeObserver(
            applicationProvider: { [application] in application },
            notificationCenterWrapper: notificationCenterWrapper,
            dispatchQueueWrapper: dispatchQueueWrapper,
            interactionShim: interactionShim
        )
    }

    /// UIKit posts `didBecomeKeyNotification` with the window as object to observers that
    /// registered without an object. The notification center double only delivers to observers
    /// registered for the same object, so deliver the notification the way NotificationCenter does.
    private func postDidBecomeKey(for window: UIWindow, to sut: SentryHingeObserver) throws {
        let invocation = try XCTUnwrap(notificationCenterWrapper.addObserverWithObjectInvocations.first)
        _ = sut.perform(invocation.selector, with: Notification(name: UIWindow.didBecomeKeyNotification, object: window))
    }

    private func testInteractions(of window: UIWindow) -> [UIInteraction] {
        window.interactions.filter { $0 is TestInteraction }
    }

    // MARK: - Availability

    func testAddObserver_whenShimUnavailable_shouldNotObserveWindows() {
        // -- Arrange --
        interactionShim.isAvailable = false
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        _ = sut.addObserver { _ in XCTFail("Handler must not be called") }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
        XCTAssertTrue(testInteractions(of: window).isEmpty)
    }

    func testRemoveObserver_whenShimUnavailable_shouldNotRemoveObservers() {
        // -- Arrange --
        interactionShim.isAvailable = false
        let sut = getSut()
        let token = sut.addObserver { _ in }
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.removeObserver(token: token)

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
    }

    func testAddObserver_whenShimReturnsNoInteraction_shouldNotAttachInteraction() {
        // -- Arrange --
        interactionShim.returnsInteraction = false
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        _ = sut.addObserver { _ in }

        // -- Assert --
        XCTAssertTrue(testInteractions(of: window).isEmpty)
    }

    // MARK: - Window Tracking

    func testAddObserver_shouldAttachInteractionToWindows() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        _ = sut.addObserver { _ in }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 1)
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.first?.name, UIWindow.didBecomeKeyNotification)
        XCTAssertEqual(testInteractions(of: window).count, 1)
    }

    func testAddObserver_whenCalledTwice_shouldAttachOneInteractionPerWindow() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        _ = sut.addObserver { _ in }
        _ = sut.addObserver { _ in }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 1)
        XCTAssertEqual(testInteractions(of: window).count, 1)
    }

    func testWindowDidBecomeKey_whenObserved_shouldAttachInteractionToNewWindow() throws {
        // -- Arrange --
        application.windows = []
        let sut = getSut()
        _ = sut.addObserver { _ in }
        let window = UIWindow(frame: .zero)

        // -- Act --
        try postDidBecomeKey(for: window, to: sut)
        try postDidBecomeKey(for: window, to: sut)

        // -- Assert --
        XCTAssertEqual(testInteractions(of: window).count, 1)
    }

    func testWindowDidBecomeKey_afterLastObserverRemoved_shouldNotAttachInteraction() throws {
        // -- Arrange --
        application.windows = []
        let sut = getSut()
        let token = sut.addObserver { _ in }
        sut.removeObserver(token: token)
        let window = UIWindow(frame: .zero)

        // -- Act --
        try postDidBecomeKey(for: window, to: sut)

        // -- Assert --
        XCTAssertTrue(testInteractions(of: window).isEmpty)
    }

    func testWindowDidBecomeKey_whenInteractionWasRemovedFromItsWindow_shouldReleaseAndReattach() throws {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()
        _ = sut.addObserver { _ in }
        weak var weakInteraction: TestInteraction?
        autoreleasepool {
            let interaction = interactionShim.interactions.first
            weakInteraction = interaction
            // A removed interaction has no view anymore, the same as one whose window deallocated.
            if let interaction {
                window.removeInteraction(interaction)
            }
        }
        XCTAssertNotNil(weakInteraction)

        // -- Act --
        try postDidBecomeKey(for: window, to: sut)

        // -- Assert --
        XCTAssertNil(weakInteraction)
        XCTAssertEqual(testInteractions(of: window).count, 1)
    }

    func testRemoveObserver_whenOtherObserversRemain_shouldKeepInteractions() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()
        let token = sut.addObserver { _ in }
        _ = sut.addObserver { _ in }
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.removeObserver(token: token)

        // -- Assert --
        XCTAssertEqual(testInteractions(of: window).count, 1)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 0)
    }

    func testRemoveObserver_whenLastObserver_shouldRemoveInteractionsAndObserver() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()
        let token = sut.addObserver { _ in }
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.removeObserver(token: token)

        // -- Assert --
        XCTAssertTrue(testInteractions(of: window).isEmpty)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 1)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.first?.name, UIWindow.didBecomeKeyNotification)
    }

    func testRemoveObserver_whenTokenUnknown_shouldNotStopObserving() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()
        _ = sut.addObserver { _ in }
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.removeObserver(token: SentryHingeObserverToken())

        // -- Assert --
        XCTAssertEqual(testInteractions(of: window).count, 1)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 0)
    }

    // MARK: - Updates

    func testCurrentState_whenNoUpdateWasObserved_shouldBeNil() {
        // -- Arrange --
        application.windows = [UIWindow(frame: .zero)]
        let sut = getSut()

        // -- Act --
        _ = sut.addObserver { _ in }

        // -- Assert --
        XCTAssertNil(sut.currentState)
    }

    func testUpdate_shouldNotifyEveryObserverAndStoreCurrentState() {
        // -- Arrange --
        application.windows = [UIWindow(frame: .zero)]
        let sut = getSut()
        var firstStates: [SentryHingeState] = []
        var secondStates: [SentryHingeState] = []
        _ = sut.addObserver { firstStates.append($0) }
        _ = sut.addObserver { secondStates.append($0) }
        let hingeState = SentryHingeState(status: .partiallyOpen, angle: 1.25)

        // -- Act --
        interactionShim.simulateUpdate(hingeState)

        // -- Assert --
        XCTAssertEqual(firstStates, [hingeState])
        XCTAssertEqual(secondStates, [hingeState])
        XCTAssertEqual(sut.currentState, hingeState)
    }

    func testUpdate_whenHingeIsNil_shouldNotNotifyObservers() {
        // -- Arrange --
        application.windows = [UIWindow(frame: .zero)]
        let sut = getSut()
        _ = sut.addObserver { _ in XCTFail("Handler must not be called") }

        // -- Act --
        interactionShim.simulateUpdate(nil)

        // -- Assert --
        XCTAssertNil(sut.currentState)
    }

    func testUpdate_afterLastObserverRemoved_shouldResetCurrentStateAndNotNotify() {
        // -- Arrange --
        application.windows = [UIWindow(frame: .zero)]
        let sut = getSut()
        var states: [SentryHingeState] = []
        let token = sut.addObserver { states.append($0) }
        interactionShim.simulateUpdate(SentryHingeState(status: .closed, angle: 0))
        sut.removeObserver(token: token)

        // -- Act --
        interactionShim.simulateUpdate(SentryHingeState(status: .fullyOpen, angle: .pi))

        // -- Assert --
        XCTAssertEqual(states.count, 1)
        XCTAssertNil(sut.currentState)
    }

    func testHingeStatus_rawValues_shouldMatchUIHingeStatus() {
        XCTAssertEqual(SentryHingeStatus.unknown.rawValue, 0)
        XCTAssertEqual(SentryHingeStatus.closed.rawValue, 1)
        XCTAssertEqual(SentryHingeStatus.partiallyOpen.rawValue, 2)
        XCTAssertEqual(SentryHingeStatus.fullyOpen.rawValue, 3)
    }
}
#endif // os(iOS)
