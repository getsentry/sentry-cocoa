#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryUIViewControllerSwizzlingHelperTests: XCTestCase {

    private var tracker: SentryUIViewControllerPerformanceTracker!

    override func setUp() {
        super.setUp()
        tracker = SentryUIViewControllerPerformanceTracker()
    }

    override func tearDown() {
        super.tearDown()
        SentryUIViewControllerSwizzlingHelper.stop()
    }

    func testSwizzleUIViewController_whenSwizzled_shouldBeActive() {
        // -- Arrange --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
        let performanceTracker = tracker!

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)

        // -- Assert --
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalled_shouldDeactivateSwizzling() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.stop()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalled_shouldClearTracker() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.stop()

        // -- Assert --
        // After stop, the tracker should be cleared and swizzling deactivated
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalledMultipleTimes_shouldNotCrash() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.stop()
        SentryUIViewControllerSwizzlingHelper.stop()
        SentryUIViewControllerSwizzlingHelper.stop()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testStop_whenCalledWithoutSwizzle_shouldNotCrash() {
        // -- Arrange --
        // No swizzling has been done

        // -- Act & Assert --
        SentryUIViewControllerSwizzlingHelper.stop()
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testUnswizzle_whenCalled_shouldDeactivateSwizzling() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.unswizzle()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testUnswizzle_whenCalled_shouldClearState() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.unswizzle()

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testSwizzleViewControllerSubClass_whenCalled_shouldNotCrash() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)

        // -- Act & Assert --
        // Swizzling a subclass should not crash
        // Note: We can't test that methods are called because unswizzle() only
        // unswizzles the base class, leaving subclasses swizzled which causes
        // infinite recursion if we call their methods after tearDown
        SentryUIViewControllerSwizzlingHelper.swizzleViewControllerSubClass(UIViewController.self)
    }

    func testSwizzlingActive_whenNotSwizzled_shouldReturnFalse() {
        // -- Arrange & Act --
        // No swizzling has been done

        // -- Assert --
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    func testSwizzlingActive_afterStopAndRestart_shouldReflectState() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        SentryUIViewControllerSwizzlingHelper.stop()
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)

        // -- Assert --
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }

    // MARK: - Init funnel (swizzleUIViewControllerInitsWithSubclassHandler:)

    func testInitFunnel_whenViewControllerInstantiated_callsHandlerSynchronouslyWithConcreteClass() {
        // -- Arrange --
        var handledClasses: [AnyClass] = []
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewControllerInits { cls in
            handledClasses.append(cls)
        }

        // -- Act --
        // Instantiating through the base designated initializer triggers the funnel.
        _ = UIViewController(nibName: nil, bundle: nil)

        // -- Assert --
        // The handler already ran by the time init returned (synchronous, no dispatch hop) — so
        // handledClasses is populated on this same line, not on a later runloop turn.
        XCTAssertTrue(handledClasses.contains { $0 == UIViewController.self },
                      "The funnel should synchronously hand the concrete class of the initialized view controller to the handler.")
    }

    func testInitFunnel_afterStop_doesNotCallHandler() {
        // -- Arrange --
        var handlerCallCount = 0
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewControllerInits { _ in
            handlerCallCount += 1
        }
        _ = UIViewController(nibName: nil, bundle: nil)
        XCTAssertGreaterThan(handlerCallCount, 0)

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.stop()
        let countAfterStop = handlerCallCount
        _ = UIViewController(nibName: nil, bundle: nil)

        // -- Assert --
        XCTAssertEqual(handlerCallCount, countAfterStop, "After stop, the funnel must no longer call the handler.")
    }

    func testUnswizzle_whenCalled_shouldUnswizzleBaseLoadView() {
        // -- Arrange --
        let performanceTracker = tracker!
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewController(withTracker: performanceTracker)

        // Verify swizzling is active before unswizzle
        XCTAssertTrue(SentryUIViewControllerSwizzlingHelper.swizzlingActive())

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.unswizzle()

        // -- Assert --
        // After unswizzle:
        // 1. The swizzlingActive flag should be false
        // 2. _tracker is set to nil by the unswizzle path (via stop)
        // 3. The base UIViewController.loadView should be unswizzled
        XCTAssertFalse(SentryUIViewControllerSwizzlingHelper.swizzlingActive())
    }
}

#endif
