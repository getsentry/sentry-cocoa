#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import ObjectiveC
@testable import Sentry
import SentryTestUtils
import XCTest

class TestViewController: UIViewController {
}

class SentryUIViewControllerPerformanceTrackerTests: XCTestCase {

    let loadView = "loadView"
    let viewWillLoad = "viewWillLoad"
    let viewDidLoad = "viewDidLoad"
    let viewWillAppear = "viewWillAppear"
    let viewDidAppear = "viewDidAppear"
    let viewWillDisappear = "viewWillDisappear"
    let viewWillLayoutSubviews = "viewWillLayoutSubviews"
    let viewDidLayoutSubviews = "viewDidLayoutSubviews"
    let layoutSubviews = "layoutSubViews"
    let spanName = "spanName"
    let spanOperation = "spanOperation"
    let origin = "auto.ui.view_controller"
    let frameDuration = 0.0016
    
    private class Fixture {
        
        var options: Options
        
        let viewController = TestViewController()
        let tracker = SentryPerformanceTracker.shared
        let dateProvider = TestCurrentDateProvider()
        
        var displayLinkWrapper = TestDisplayLinkWrapper()
        var framesTracker: SentryFramesTracker
        
        var viewControllerName: String!

        var inAppLogic: SentryInAppLogic {
            return SentryInAppLogic(inAppIncludes: options.inAppIncludes, inAppExcludes: [])
        }
        
        init() {
            options = Options.noIntegrations()
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
            options.debug = true
            
            framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                                                notificationCenter: TestNSNotificationCenterWrapper(), keepDelayedFramesDuration: 0)
            SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
            framesTracker.start()
        }
                
        func getSut() -> SentryUIViewControllerPerformanceTracker {
            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
            
            viewControllerName = SwiftDescriptor.getObjectClassName(viewController)
            SentryUIViewControllerPerformanceTracker.shared.inAppLogic = self.inAppLogic
            return SentryUIViewControllerPerformanceTracker.shared
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
    
    func testUILifeCycle_ViewDidAppear() throws {
        try assertUILifeCycle(finishStatus: SentrySpanStatus.ok) { sut, viewController, tracker, callbackExpectation, transactionSpan in
            sut.viewControllerViewDidAppear(viewController) {
                let blockSpan = self.getStack(tracker).last!
                XCTAssertEqual(blockSpan.parentSpanId, transactionSpan.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewDidAppear)
                XCTAssertEqual(blockSpan.origin, self.origin)
                callbackExpectation.fulfill()
            }

            // Simulate call to viewWillDisappear later on. As the transaction is already
            // finished above in viewDidAppear nothing should happend here.
            sut.viewControllerViewWillDisappear(viewController) {
                self.assertTrackerIsEmpty(tracker)
            }
        }
    }

    func testUILifeCycle_NoViewDidAppear_OnlyViewWillDisappear() throws {
        // Don't call viewDidAppear on purpose.

        try assertUILifeCycle(finishStatus: SentrySpanStatus.cancelled) { sut, viewController, tracker, callbackExpectation, transactionSpan in
            sut.viewControllerViewWillDisappear(viewController) {
                let blockSpan = self.getStack(tracker).last!
                XCTAssertEqual(blockSpan.parentSpanId, transactionSpan.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewWillDisappear)
                XCTAssertEqual(blockSpan.origin, self.origin)
                callbackExpectation.fulfill()
            }
        }
    }

    private func assertUILifeCycle(finishStatus: SentrySpanStatus, lifecycleEndingMethod: (SentryUIViewControllerPerformanceTracker, UIViewController, SentryPerformanceTracker, XCTestExpectation, Span) -> Void) throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
                
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 6
        
        XCTAssertTrue(getStack(tracker).isEmpty)
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            transactionSpan = spans.first
            if let blockSpan = spans.last, let transactionSpan = transactionSpan {
                XCTAssertEqual(blockSpan.parentSpanId, transactionSpan.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.loadView)
                XCTAssertEqual(blockSpan.origin, self.origin)
            } else {
                XCTFail("Expected spans")
            }
            callbackExpectation.fulfill()
        }
        let tracer = try XCTUnwrap(transactionSpan as? SentryTracer)
        XCTAssertEqual(tracer.transactionContext.name, fixture.viewControllerName)
        XCTAssertEqual(tracer.transactionContext.nameSource, .component)
        XCTAssertEqual(tracer.transactionContext.origin, origin)
        XCTAssertFalse(tracer.isFinished)
        
        let config = try XCTUnwrap(Dynamic(tracer).configuration.asObject as? SentryTracerConfiguration)
        XCTAssertTrue(config.finishMustBeCalled)

        sut.viewControllerViewDidLoad(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.parentSpanId, tracer.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewDidLoad)
                XCTAssertEqual(blockSpan.origin, self.origin)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.parentSpanId, tracer.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewWillLayoutSubviews)
                XCTAssertEqual(blockSpan.origin, self.origin)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)

        let layoutSubViewsSpan = try XCTUnwrap((Dynamic(transactionSpan).children as [Span]?)?.last)
        XCTAssertEqual(layoutSubViewsSpan.parentSpanId, tracer.spanId)
        XCTAssertEqual(layoutSubViewsSpan.spanDescription, self.layoutSubviews)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.parentSpanId, tracer.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewDidLayoutSubviews)
                XCTAssertEqual(blockSpan.origin, self.origin)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.parentSpanId, tracer.spanId)
                XCTAssertEqual(blockSpan.spanDescription, self.viewWillAppear)
                XCTAssertEqual(blockSpan.origin, self.origin)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)

        reportFrame()

        lifecycleEndingMethod(sut, viewController, tracker, callbackExpectation, tracer)

        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 8)
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(finishStatus.rawValue, tracer.status.rawValue)

        wait(for: [callbackExpectation], timeout: 0)

        assertTrackerIsEmpty(tracker)
    }
    
    func testTimeMeasurement() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
        
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 6
                
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 0))
        var lastSpan: Span?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker).first
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 1)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 1)
        
        sut.viewControllerViewDidLoad(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 3)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 3)
        
        let layoutSubViewsSpan = try XCTUnwrap((Dynamic(transactionSpan).children as [Span]?)?.last)
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 2)
        try assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 1)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 1)
        reportFrame()
        advanceTime(bySeconds: 4)

        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 5)
            callbackExpectation.fulfill()
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 5)
        try assertSpanDuration(span: transactionSpan, expectedDuration: 22 + frameDuration)
        
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testReportInitialDisplay_WhenViewWillAppear() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var tracer: SentryTracer?

        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            tracer = spans.first as? SentryTracer
        }
        sut.viewControllerViewWillAppear(viewController) {
            self.advanceTime(bySeconds: 0.1)
        }

        reportFrame()
        let expectedTTIDTimestamp = fixture.dateProvider.date()
        
        let children: [Span]? = Dynamic(tracer).children as [Span]?

        let ttidSpan = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", ttidSpan.operation)
        XCTAssertEqual("TestViewController initial display", ttidSpan.spanDescription)
        XCTAssertEqual(expectedTTIDTimestamp, ttidSpan.timestamp)
        XCTAssertTrue(ttidSpan.isFinished)
    }
    
    func testReportInitialDisplay_WhenViewWillAppearSkipped_WillLayoutSubViewsCalled() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var tracer: SentryTracer?

        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            tracer = spans.first as? SentryTracer
        }
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            self.advanceTime(bySeconds: 0.1)
        }

        reportFrame()
        let expectedTTIDTimestamp = fixture.dateProvider.date()
        
        let children: [Span]? = Dynamic(tracer).children as [Span]?

        let ttidSpan = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", ttidSpan.operation)
        XCTAssertEqual("TestViewController initial display", ttidSpan.spanDescription)
        XCTAssertEqual(expectedTTIDTimestamp, ttidSpan.timestamp)
        XCTAssertTrue(ttidSpan.isFinished)
    }
    
    func testReportInitialDisplay_WhenViewWillAppearAndWillLayoutSubviews() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var tracer: SentryTracer?

        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            tracer = spans.first as? SentryTracer
        }
        sut.viewControllerViewWillAppear(viewController) {
            self.advanceTime(bySeconds: 0.1)
        }

        reportFrame()
        let expectedTTIDTimestamp = fixture.dateProvider.date()
        
        // It's doubtful that the OS renders a frame between viewWillAppear and viewWillLayoutSubViews, but if it does, we need to pick the end TTID on viewWillAppear.
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            self.advanceTime(bySeconds: 0.1)
        }
        
        let children: [Span]? = Dynamic(tracer).children as [Span]?

        let ttidSpan = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", ttidSpan.operation)
        XCTAssertEqual("TestViewController initial display", ttidSpan.spanDescription)
        XCTAssertEqual(expectedTTIDTimestamp, ttidSpan.timestamp)
        XCTAssertTrue(ttidSpan.isFinished)
    }
    
    func testReportFullyDisplayed() throws {
        let sut = fixture.getSut()
        sut.enableWaitForFullDisplay = true
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var tracer: SentryTracer?

        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            tracer = spans.first as? SentryTracer
        }
        sut.viewControllerViewWillAppear(viewController) {
            self.advanceTime(bySeconds: 0.1)
        }

        sut.reportFullyDisplayed()
        reportFrame()
        let expectedTTFDTimestamp = fixture.dateProvider.date()

        let ttfdSpan = try XCTUnwrap(tracer?.children.element(at: 1))
        XCTAssertEqual(ttfdSpan.isFinished, true)
        XCTAssertEqual(ttfdSpan.timestamp, expectedTTFDTimestamp)
    }
    
    func testFramesTrackerNotRunning_NoTTDTrackerAndSpans() {
        fixture.framesTracker.stop()
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let viewController = fixture.viewController
        var tracer: SentryTracer?
        
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            tracer = spans.first as? SentryTracer
        }

        let ttdTracker = Dynamic(sut).currentTTDTracker.asObject as? SentryTimeToDisplayTracker
        XCTAssertNil(ttdTracker)
        
        sut.reportFullyDisplayed()
        
        XCTAssertEqual(tracer?.children.filter { $0.operation.contains("initial_display") }.count, 0, "Tracer must not contain a TTID span")
        XCTAssertEqual(tracer?.children.filter { $0.operation.contains("full_display") }.count, 0, "Tracer must not contain a TTFD span")
    }

    func testSecondViewController() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let viewController2 = TestViewController()
        
        sut.viewControllerLoadView(viewController) {
            //Left empty on purpose
        }

        let ttdTracker = Dynamic(sut).currentTTDTracker.asObject as? SentryTimeToDisplayTracker
        XCTAssertNotNil(ttdTracker)

        sut.viewControllerLoadView(viewController2) {
            //Left empty on purpose
        }

        let secondTTDTracker = objc_getAssociatedObject(viewController2, SENTRY_UI_PERFORMANCE_TRACKER_TTD_TRACKER)

        XCTAssertEqual(ttdTracker, Dynamic(sut).currentTTDTracker.asObject)
        XCTAssertNil(secondTTDTracker)
    }
    
    func testTimeMeasurement_SkipLoadView() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
                
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 0))
        var lastSpan: Span?
        
        sut.viewControllerViewDidLoad(viewController) {
            transactionSpan = self.getStack(tracker).first
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)

        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 3)
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 3)
        
        let layoutSubViewsSpan = try XCTUnwrap((Dynamic(transactionSpan).children as [Span]?)?.last)
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 2)
        try assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 1)
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 1)
        
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 5)
        }
        try assertSpanDuration(span: lastSpan, expectedDuration: 5)
        try assertSpanDuration(span: transactionSpan, expectedDuration: 21)

        assertTrackerIsEmpty(tracker)
    }
    
    func testWaitingForCustomSpan() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
        
        var lastSpan: Span?
        var customSpanId: SpanId?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker).first
            lastSpan = self.getStack(tracker).last
            customSpanId = tracker.startSpan(withName: self.spanName, nameSource: .custom, operation: self.spanOperation, origin: self.origin)
        }
        let unwrappedLastSpan = try XCTUnwrap(lastSpan)
        XCTAssertTrue(unwrappedLastSpan.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            //intentionally left empty.
        }
        reportFrame()
        sut.viewControllerViewDidAppear(viewController) {
            //intentionally left empty.
            //Need to call viewControllerViewDidAppear to finish the transaction.
        }

        let unwrappedTransactionSpan = try XCTUnwrap(transactionSpan)
        let unwrappedCustomSpanId = try XCTUnwrap(customSpanId)
        XCTAssertFalse(unwrappedTransactionSpan.isFinished)
        tracker.finishSpan(unwrappedCustomSpanId)
        XCTAssertTrue(unwrappedTransactionSpan.isFinished)

        let children = try XCTUnwrap(Dynamic(unwrappedTransactionSpan).children.asArray)
        XCTAssertEqual(children.count, 5)

        assertTrackerIsEmpty(tracker)
    }
    
    func testSkipLoadViewAndViewDidLoad() {
        //Skipping loadView prevent the tracker from creating the view controller transaction and no span is created after this.
        
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            XCTAssertTrue(self.getStack(tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            XCTAssertTrue(self.getStack(tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerViewWillAppear(viewController) {
            XCTAssertTrue(self.getStack(tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerViewDidAppear(viewController) {
            XCTAssertTrue(self.getStack(tracker).isEmpty)
        }

        assertTrackerIsEmpty(tracker)
    }
    
    func testSpanAssociatedConstants() {
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID")
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID")
    }
    
    func testOverloadCall() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
        
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 3
        
        XCTAssertTrue(getStack(tracker).isEmpty)
        //we need loadView to start the tracking
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            transactionSpan = spans.first
            
            callbackExpectation.fulfill()
        }
        
        var unwrappedTransactionSpan = try XCTUnwrap(transactionSpan)
        XCTAssertFalse(unwrappedTransactionSpan.isFinished)
        
        sut.viewControllerViewDidLoad(viewController) {
            let blockSpan = self.getStack(tracker).last!
            
            //this is the same as calling super.viewDidLoad in a custom class sub class
            sut.viewControllerViewDidLoad(viewController) {
                let innerblockSpan = self.getStack(tracker).last!
                XCTAssertTrue(innerblockSpan === blockSpan)
                
                callbackExpectation.fulfill()
            }
            
            callbackExpectation.fulfill()
        }

        unwrappedTransactionSpan = try XCTUnwrap(transactionSpan)
        XCTAssertFalse(unwrappedTransactionSpan.isFinished)
        XCTAssertEqual(Dynamic(unwrappedTransactionSpan).children.asArray!.count, 3)

        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testLoadView_withNonInAppUIViewController_DoesNotStartTransaction() {
        let sut = fixture.getSut()
        let viewController = UIViewController()
        let tracker = fixture.tracker
        var transactionSpan: Span!
        let callbackExpectation = expectation(description: "Callback Expectation")
        
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            transactionSpan = spans.first
            callbackExpectation.fulfill()
        }
               
        XCTAssertNil(transactionSpan)
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testLoadView_withIgnoreSwizzleUIViewController_DoesNotStartTransaction() {
        fixture.options.swizzleClassNameExcludes = ["TestViewController"]
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        let callbackExpectation = expectation(description: "Callback Expectation")
        
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            transactionSpan = spans.first
            callbackExpectation.fulfill()
        }
               
        XCTAssertNil(transactionSpan, "Expected to transaction.")
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testSecondLoadView() throws {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 2
        
        XCTAssertTrue(getStack(tracker).isEmpty)
        
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker)
            transactionSpan = spans.first
            callbackExpectation.fulfill()
        }
        
        //here we are calling loadView a second time,
        //which should create a child span of the transaction
        //already created in the previous call and not create a new transaction
        sut.viewControllerLoadView(viewController) {
            //This callback was intentionally left blank
            callbackExpectation.fulfill()
        }

        let children = try XCTUnwrap(Dynamic(transactionSpan).children.asArray)
        XCTAssertEqual(children.count, 3)
        wait(for: [callbackExpectation], timeout: 0)
    }

    func test_waitForFullDisplay() {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let firstController = TestViewController()

        var tracer: SentryTracer?

        sut.enableWaitForFullDisplay = true

        sut.viewControllerLoadView(firstController) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }
        XCTAssertEqual(tracer?.children.count, 3)
        XCTAssertEqual(try XCTUnwrap(tracer?.children.element(at: 1)).operation, "ui.load.full_display")
        XCTAssertEqual(try XCTUnwrap(tracer?.children.element(at: 1)).origin, "manual.ui.time_to_display")
    }

    func test_dontWaitForFullDisplay() {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let firstController = TestViewController()

        var tracer: SentryTracer?

        sut.enableWaitForFullDisplay = false

        sut.viewControllerLoadView(firstController) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }

        XCTAssertEqual(tracer?.children.count, 2)
    }
    
    func test_OnlyViewDidLoad_CreatesTTIDSpan() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker

        var tracer: SentryTracer!

        sut.viewControllerViewDidLoad(TestViewController()) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }

        let children: [Span]? = Dynamic(tracer).children as [Span]?

        XCTAssertEqual(children?.count, 2)
        
        let firstChild = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", firstChild.operation)
        XCTAssertEqual("TestViewController initial display", firstChild.spanDescription)
        let secondChild = try XCTUnwrap(children?[1])
        XCTAssertEqual("ui.load", secondChild.operation)
        XCTAssertEqual("viewDidLoad", secondChild.spanDescription)
    }
    
    func test_OnlyViewDidLoadTTFDEnabled_CreatesTTIDAndTTFDSpans() throws {
        let sut = fixture.getSut()
        sut.enableWaitForFullDisplay = true
        let tracker = fixture.tracker

        var tracer: SentryTracer!

        sut.viewControllerViewDidLoad(TestViewController()) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }

        let children: [Span]? = Dynamic(tracer).children as [Span]?

        XCTAssertEqual(children?.count, 3)
        
        let child1 = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", child1.operation)
        XCTAssertEqual("TestViewController initial display", child1.spanDescription)
        
        let child2 = try XCTUnwrap(children?[1])
        XCTAssertEqual("ui.load.full_display", child2.operation)
        XCTAssertEqual("TestViewController full display", child2.spanDescription)
        
        let child3 = try XCTUnwrap(children?[2])
        XCTAssertEqual("ui.load", child3.operation)
        XCTAssertEqual("viewDidLoad", child3.spanDescription)
    }
    
    func test_BothLoadViewAndViewDidLoad_CreatesOneTTIDSpan() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let controller = TestViewController()
        var tracer: SentryTracer!
        
        sut.viewControllerLoadView(controller) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }

        sut.viewControllerViewDidLoad(controller) {
            // Empty on purpose
        }

        let children: [Span]? = Dynamic(tracer).children as [Span]?

        XCTAssertEqual(children?.count, 3)
        
        let child1 = try XCTUnwrap(children?.first)
        XCTAssertEqual("ui.load.initial_display", child1.operation)
        
        let child2 = try XCTUnwrap(children?[1])
        XCTAssertEqual("ui.load", child2.operation)
        XCTAssertEqual("loadView", child2.spanDescription)
        
        let child3 = try XCTUnwrap(children?[2])
        XCTAssertEqual("ui.load", child3.operation)
        XCTAssertEqual("viewDidLoad", child3.spanDescription)
    }
    
    func test_waitForFullDisplay_NewViewControllerLoaded_BeforeReportTTFD() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let firstController = TestViewController()
        let secondController = TestViewController()

        var firstTracer: SentryTracer?
        var secondTracer: SentryTracer?

        sut.enableWaitForFullDisplay = true

        sut.viewControllerLoadView(firstController) {
            firstTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        sut.viewControllerViewDidLoad(firstController) {
            // Empty on purpose
        }
        
        sut.viewControllerViewWillAppear(firstController) {
            // Empty on purpose
        }
        
        sut.viewControllerViewDidAppear(firstController) {
            // Empty on purpose
        }
        
        let firstFullDisplaySpan = try XCTUnwrap(firstTracer?.children.first { $0.operation == "ui.load.full_display" })

        XCTAssertFalse(firstFullDisplaySpan.isFinished)
        
        XCTAssertEqual(firstTracer?.traceId, SentrySDK.span?.traceId)

        sut.viewControllerLoadView(secondController) {
            secondTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        XCTAssertEqual(secondTracer?.traceId, SentrySDK.span?.traceId)
        
        XCTAssertTrue(firstFullDisplaySpan.isFinished)
        XCTAssertEqual(.deadlineExceeded, firstFullDisplaySpan.status)
        
        let secondFullDisplaySpan = try XCTUnwrap(secondTracer?.children.first { $0.operation == "ui.load.full_display" })
        
        XCTAssertFalse(secondFullDisplaySpan.isFinished)
    }
    
    func test_waitForFullDisplay_NewViewControllerLoaded_BeforeReportTTFD_FramesTrackerStopped() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let firstController = TestViewController()
        let secondController = TestViewController()

        var firstTracer: SentryTracer?
        var secondTracer: SentryTracer?

        sut.enableWaitForFullDisplay = true

        sut.viewControllerLoadView(firstController) {
            firstTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        sut.viewControllerViewDidLoad(firstController) {
            // Empty on purpose
        }
        
        sut.viewControllerViewWillAppear(firstController) {
            // Empty on purpose
        }
        
        sut.viewControllerViewDidAppear(firstController) {
            // Empty on purpose
        }
        
        let firstFullDisplaySpan = try XCTUnwrap(firstTracer?.children.first { $0.operation == "ui.load.full_display" })

        XCTAssertFalse(firstFullDisplaySpan.isFinished)
        
        fixture.framesTracker.stop()
        
        sut.viewControllerLoadView(secondController) {
            secondTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        XCTAssertEqual(secondTracer?.traceId, SentrySDK.span?.traceId)
        XCTAssertTrue(firstTracer?.isFinished ?? false)
        XCTAssertTrue(firstFullDisplaySpan.isFinished)
        XCTAssertEqual(.deadlineExceeded, firstFullDisplaySpan.status)
        
        XCTAssertEqual(0, secondTracer?.children.filter { $0.operation == "ui.load.full_display" }.count, "There should be no full display span, because the frames tracker is not running.")
    }
    
    func test_waitForFullDisplay_NestedUIViewControllers_DoesNotFinishTTFDSpan() throws {
        let sut = fixture.getSut()
        let tracker = fixture.tracker
        let firstController = TestViewController()
        let secondController = TestViewController()

        var firstTracer: SentryTracer?
        var secondTracer: SentryTracer?

        sut.enableWaitForFullDisplay = true

        sut.viewControllerLoadView(firstController) {
            firstTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        sut.viewControllerViewDidLoad(firstController) {
            // Empty on purpose
        }
        
        sut.viewControllerViewWillAppear(firstController) {
            // Empty on purpose
        }
        
        let firstFullDisplaySpan = try XCTUnwrap(firstTracer?.children.first { $0.operation == "ui.load.full_display" })

        XCTAssertFalse(firstFullDisplaySpan.isFinished)
        
        sut.viewControllerLoadView(secondController) {
            secondTracer = self.getStack(tracker).first as? SentryTracer
        }
        
        XCTAssertEqual(firstTracer?.traceId, secondTracer?.traceId, "First and second tracer should have the same trace id as the second view controller is nested in the first one.")
        
        XCTAssertEqual(firstTracer?.traceId.sentryIdString, SentrySDK.span?.traceId.sentryIdString)
        
        XCTAssertFalse(firstTracer?.isFinished ?? true)
        XCTAssertFalse(firstFullDisplaySpan.isFinished)
    }

    func test_captureAllAutomaticSpans() {
        let sut = fixture.getSut()
        let firstController = TestViewController()
        let secondController = TestViewController()
        let thirdController = TestViewController()
        let tracker = fixture.tracker

        var tracer: SentryTracer!

        //The first view controller creates a transaction
        sut.viewControllerViewDidLoad(firstController) {
            tracer = self.getStack(tracker).first as? SentryTracer
        }

        //The second view controller should be part of the current transaction
        //even though it's not happening inside one of the ui life cycle functions
        sut.viewControllerViewDidLoad(secondController) {
            guard let spanId = tracker.activeSpanId(),
                  let viewDidLoadSpan = tracker.getSpan(spanId),
                  let viewDidLoadSpanParent = viewDidLoadSpan.parentSpanId,
                  let secondVCSpan = tracker.getSpan(viewDidLoadSpanParent) else {
                XCTFail("Could not get the second controller span")
                return
            }
            XCTAssertEqual(tracer.spanId, secondVCSpan.parentSpanId)
        }

        //The third view controller should also be a child of the first span
        sut.viewControllerViewDidLoad(thirdController) {
            guard let spanId = tracker.activeSpanId(),
                  let viewDidLoadSpan = tracker.getSpan(spanId),
                  let viewDidLoadSpanParent = viewDidLoadSpan.parentSpanId,
                  let secondVCSpan = tracker.getSpan(viewDidLoadSpanParent) else {
                XCTFail("Could not get the third controller span")
                return
            }
            XCTAssertEqual(tracer.spanId, secondVCSpan.parentSpanId)
        }

        let children: [Span]? = Dynamic(tracer).children as [Span]?

        // First Controller initial_display
        // First Controller viewDidLoad
        // Second Controller root span
        // Second Controller viewDidLoad
        // Third Controller root span
        // Third Controller viewDidLoad
        XCTAssertEqual(children?.count, 6)
    }

    private func assertSpanDuration(span: Span?, expectedDuration: TimeInterval) throws {
        let span = try XCTUnwrap(span)
        let timestamp = try XCTUnwrap(span.timestamp)
        let startTimestamp = try XCTUnwrap(span.startTimestamp)
        let duration = timestamp.timeIntervalSince(startTimestamp)
        XCTAssertEqual(duration, expectedDuration, accuracy: 0.001)
    }
    
    private func assertTrackerIsEmpty(_ tracker: SentryPerformanceTracker) {
        XCTAssertEqual(0, getStack(tracker).count)
        XCTAssertEqual(0, getSpans(tracker).count)
    }

    private func getStack(_ tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeSpanStack as [Span]?
        return result!
    }

    private func getSpans(_ tracker: SentryPerformanceTracker) -> [SpanId: Span] {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }

    private func reportFrame() {
        advanceTime(bySeconds: self.frameDuration)
        Dynamic(SentryDependencyContainer.sharedInstance().framesTracker).displayLinkCallback()
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
