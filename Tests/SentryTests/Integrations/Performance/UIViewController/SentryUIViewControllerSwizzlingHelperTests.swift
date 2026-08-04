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

    // MARK: - Init funnel (swizzleUIViewControllerInitsWithInitHandler:)

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

    func testInitFunnel_whenViewControllersInstantiated_doesNotOverRetainThem() throws {
        // The funnel replaces two init-family methods, which return +1 (ns_returns_retained), while
        // the replacement block is declared `id`-returning and therefore +0 autoreleased at the ABI
        // level. This test pins down that the resulting retain handshake stays balanced: an
        // over-retain would leak every view controller the host app ever creates.
        //
        // -- Arrange --
        var handlerCallCount = 0
        SentryUIViewControllerSwizzlingHelper.swizzleUIViewControllerInits { _ in
            handlerCallCount += 1
        }

        weak var weakNibViewController: UIViewController?
        weak var weakCoderViewController: UIViewController?

        // -- Act --
        try autoreleasepool {
            let nibViewController = UIViewController(nibName: nil, bundle: nil)
            weakNibViewController = nibViewController

            // Round-trip through NSKeyedArchiver so the instance is created via initWithCoder:, the
            // funnel's second swizzled initializer.
            let archiver = NSKeyedArchiver(requiringSecureCoding: false)
            archiver.encode(nibViewController, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()

            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
            unarchiver.requiresSecureCoding = false
            let coderViewController = try XCTUnwrap(
                unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? UIViewController,
                "Expected the archived view controller to decode via initWithCoder:."
            )
            weakCoderViewController = coderViewController
        }

        // -- Assert --
        // Guard against a vacuous pass: if the funnel never intercepted these initializers, the
        // deallocation assertions below would prove nothing about the swizzled code path.
        XCTAssertGreaterThanOrEqual(handlerCallCount, 2, "Both view controllers should have been routed through the funnel.")
        XCTAssertNil(weakNibViewController, "A view controller created via initWithNibName:bundle: must deallocate; the funnel must not retain it.")
        XCTAssertNil(weakCoderViewController, "A view controller created via initWithCoder: must deallocate; the funnel must not retain it.")
    }

    func testStop_whenInitFunnelInstalled_shouldRestoreBaseInitializerImplementations() throws {
        // The funnel replaces two initializers on the BASE UIViewController, so leaving them
        // installed leaks into every later test suite in the same run. Anything that resets global
        // SDK state (clearTestState) relies on stop actually restoring them, not just clearing the
        // handler.
        //
        // -- Arrange --
        let nibSelector = NSSelectorFromString("initWithNibName:bundle:")
        let coderSelector = NSSelectorFromString("initWithCoder:")

        // imp_getBlock returns the block of an IMP created via imp_implementationWithBlock, which is
        // how SentrySwizzle builds its replacements, and nil for UIKit's own compiled IMP. That
        // distinguishes a swizzled initializer from the original one.
        XCTAssertNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, nibSelector))),
                     "initWithNibName:bundle: must not be swizzled before the funnel is installed; a previous test suite leaked it.")
        XCTAssertNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, coderSelector))),
                     "initWithCoder: must not be swizzled before the funnel is installed; a previous test suite leaked it.")

        SentryUIViewControllerSwizzlingHelper.swizzleUIViewControllerInits { _ in }

        XCTAssertNotNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, nibSelector))),
                        "The funnel should have replaced initWithNibName:bundle: with a block-based IMP.")
        XCTAssertNotNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, coderSelector))),
                        "The funnel should have replaced initWithCoder: with a block-based IMP.")

        // -- Act --
        SentryUIViewControllerSwizzlingHelper.stop()

        // -- Assert --
        XCTAssertNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, nibSelector))),
                     "stop must restore UIKit's initWithNibName:bundle:, otherwise the funnel leaks into later test suites.")
        XCTAssertNil(imp_getBlock(try XCTUnwrap(class_getMethodImplementation(UIViewController.self, coderSelector))),
                     "stop must restore UIKit's initWithCoder:, otherwise the funnel leaks into later test suites.")
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
