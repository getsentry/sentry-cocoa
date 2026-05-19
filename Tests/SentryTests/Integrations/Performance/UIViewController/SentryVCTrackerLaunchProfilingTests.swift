#if os(iOS) || os(tvOS) || os(visionOS)

import ObjectiveC
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryVCTrackerLaunchProfilingTests: XCTestCase {

    private let frameDuration = 0.0016

    private class Fixture {
        var options: Options
        let viewController = TestViewController()
        let tracker = SentryPerformanceTracker.shared
        let dateProvider = TestCurrentDateProvider()
        var displayLinkWrapper = TestDisplayLinkWrapper()
        var framesTracker: SentryFramesTracker
        var viewControllerName: String!

        var inAppLogic: SentryInAppLogic {
            return SentryInAppLogic(inAppIncludes: options.inAppIncludes)
        }

        init() {
            options = Options.noIntegrations()
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
            options.debug = true

            framesTracker = SentryFramesTracker(
                displayLinkWrapper: displayLinkWrapper,
                dateProvider: dateProvider,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                notificationCenter: TestNSNotificationCenterWrapper(),
                delayedFramesTracker: TestDelayedWrapper(
                    keepDelayedFramesDuration: 0,
                    dateProvider: dateProvider
                )
            )
            SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
            framesTracker.start()
        }

        func getSut() -> SentryUIViewControllerPerformanceTracker {
            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider

            viewControllerName = SwiftDescriptor.getObjectClassName(viewController)
            let performanceTracker = SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker
            performanceTracker.inAppLogic = self.inAppLogic
            return performanceTracker
        }

        func makeLaunchTracer(hub: SentryHubInternal) -> SentryTracer {
            let context = TransactionContext(
                name: "launch",
                nameSource: .custom,
                operation: SentrySpanOperationAppLifecycle,
                origin: "auto.app.start.profile"
            )
            return SentryTracer(
                transactionContext: context,
                hub: hub,
                configuration: SentryTracerConfiguration(block: {
                    $0.waitForChildren = true
                })
            )
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.start(options: fixture.options)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_vcSpanBecomesChildOfLaunchTracer() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController

        let hub = SentrySDKInternal.currentHub()
        let launchTracer = fixture.makeLaunchTracer(hub: hub)
        sentry_launchTracer = launchTracer

        sut.viewControllerLoadView(viewController) { }

        let vcSpan = try XCTUnwrap(
            launchTracer.children.first { $0.operation == "ui.load" },
            "VC span must be a child of the launch tracer"
        )
        XCTAssertEqual(vcSpan.parentSpanId, launchTracer.spanId)
    }

    func test_launchTracerChild_notPushedOntoActiveSpanStack() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let viewController = fixture.viewController

        let hub = SentrySDKInternal.currentHub()
        let launchTracer = fixture.makeLaunchTracer(hub: hub)
        sentry_launchTracer = launchTracer

        sut.viewControllerLoadView(viewController) { }

        XCTAssertTrue(
            getStack(tracker).isEmpty,
            "Launch tracer children must not be pushed onto the active span stack"
        )
    }

    func test_ttdTrackerCreated_forLaunchTracerChild() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController

        let hub = SentrySDKInternal.currentHub()
        let launchTracer = fixture.makeLaunchTracer(hub: hub)
        sentry_launchTracer = launchTracer

        sut.viewControllerLoadView(viewController) { }

        let ttdTracker = Dynamic(Dynamic(sut).helper)
            .currentTTDTracker.asObject as? SentryTimeToDisplayTracker
        XCTAssertNotNil(
            ttdTracker,
            "TTD tracker must be created for VC spans that are children of the launch tracer"
        )

        let ttidSpan = try XCTUnwrap(
            launchTracer.children.first { $0.operation == "ui.load.initial_display" }
        )
        XCTAssertFalse(ttidSpan.isFinished)

        sut.viewControllerViewWillAppear(viewController) { }
        reportFrame()

        XCTAssertTrue(ttidSpan.isFinished, "TTID span must finish after initial display + frame")
    }

    func test_afterLaunchTracerCleared_nextVC_getsOwnRootTransaction() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let viewController = fixture.viewController

        let hub = SentrySDKInternal.currentHub()
        let launchTracer = fixture.makeLaunchTracer(hub: hub)
        sentry_launchTracer = launchTracer

        sut.viewControllerLoadView(viewController) { }
        sut.viewControllerViewWillAppear(viewController) { }
        reportFrame()

        sentry_launchTracer = nil

        sut.viewControllerViewDidAppear(viewController) { }

        let secondController = TestViewController()
        var secondVCSpan: Span?
        sut.viewControllerLoadView(secondController) {
            secondVCSpan = self.getStack(tracker).first
        }

        let span = try XCTUnwrap(secondVCSpan)
        XCTAssertNil(
            span.parentSpanId,
            "Second VC must be a root transaction after launch tracer is cleared"
        )
        XCTAssertFalse(
            getStack(tracker).isEmpty,
            "Root transaction must be pushed onto the active span stack"
        )

        let secondTracer = try XCTUnwrap(span as? SentryTracer)
        XCTAssertNotEqual(secondTracer.traceId, launchTracer.traceId)
    }

    // MARK: - Helpers

    private func getStack(_ tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeSpanStack as [Span]?
        return result!
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(
            date: fixture.dateProvider.date().addingTimeInterval(bySeconds)
        )
    }

    private func reportFrame() {
        advanceTime(bySeconds: self.frameDuration)
        Dynamic(SentryDependencyContainer.sharedInstance().framesTracker).displayLinkCallback()
    }
}

#endif
