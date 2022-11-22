import ObjectiveC
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestViewController: UIViewController {
}

class SentryUIViewControllerPerformanceTrackerTests: XCTestCase {

    let loadView = "loadView"
    let viewWillLoad = "viewWillLoad"
    let viewDidLoad = "viewDidLoad"
    let viewWillAppear = "viewWillAppear"
    let viewAppearing = "viewAppearing"
    let viewDidAppear = "viewDidAppear"
    let viewWillDisappear = "viewWillDisappear"
    let viewWillLayoutSubviews = "viewWillLayoutSubviews"
    let viewDidLayoutSubviews = "viewDidLayoutSubviews"
    let layoutSubviews = "layoutSubViews"
    let spanName = "spanName"
    let spanOperation = "spanOperation"
    
    private class Fixture {
        
        var options: Options {
            let options = Options()
            let imageName = String(
                cString: class_getImageName(SentryUIViewControllerSwizzlingTests.self)!,
                encoding: .utf8)! as NSString
            options.add(inAppInclude: imageName.lastPathComponent)
            return options
        }
        
        let viewController = TestViewController()
        let tracker = SentryPerformanceTracker()
        let dateProvider = TestCurrentDateProvider()
        
        var viewControllerName: String!
                
        func getSut() -> SentryUIViewControllerPerformanceTracker {
            CurrentDate.setCurrentDateProvider(dateProvider)
            
            viewControllerName = SentryUIViewControllerSanitizer.sanitizeViewControllerName(viewController)
        
            let result = SentryUIViewControllerPerformanceTracker.shared
            Dynamic(result).tracker = self.tracker
            
            return result
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
    
    func testUILifeCycle_ViewDidAppear() {
        assertUILifeCycle(finishStatus: SentrySpanStatus.ok) { sut, viewController, tracker, callbackExpectation, transactionSpan in
            sut.viewControllerViewDidAppear(viewController) {
                let blockSpan = self.getStack(tracker).last!
                XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidAppear)
                callbackExpectation.fulfill()
            }

            // Simulate call to viewWillDisappear later on. As the transaction is already
            // finished above in viewDidAppear nothing should happend here.
            sut.viewControllerViewWillDisappear(viewController) {
                self.assertTrackerIsEmpty(tracker)
            }
        }
    }

    func testUILifeCycle_NoViewDidAppear_OnlyViewWillDisappear() {
        // Don't call viewDidAppear on purpose.

        assertUILifeCycle(finishStatus: SentrySpanStatus.cancelled) { sut, viewController, tracker, callbackExpectation, transactionSpan in
            sut.viewControllerViewWillDisappear(viewController) {
                let blockSpan = self.getStack(tracker).last!
                XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewWillDisappear)
                callbackExpectation.fulfill()
            }
        }
    }

    private func assertUILifeCycle(finishStatus: SentrySpanStatus, lifecycleEndingMethod: (SentryUIViewControllerPerformanceTracker, UIViewController, SentryPerformanceTracker, XCTestExpectation, Span) -> Void) {
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
                XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.loadView)
            } else {
                XCTFail("Expected spans")
            }
            callbackExpectation.fulfill()
        }
        guard let tracer = transactionSpan as? SentryTracer else {
            XCTFail("Expected a tracer")
            return
        }
        XCTAssertEqual(tracer.transactionContext.name, fixture.viewControllerName)
        XCTAssertEqual(tracer.transactionContext.nameSource, .component)
        XCTAssertFalse(tracer.isFinished)

        sut.viewControllerViewDidLoad(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.context.parentSpanId, tracer.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidLoad)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.context.parentSpanId, tracer.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewWillLayoutSubviews)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)

        if let layoutSubViewsSpan = (Dynamic(transactionSpan).children as [Span]?)?.last {
            XCTAssertEqual(layoutSubViewsSpan.context.parentSpanId, tracer.context.spanId)
            XCTAssertEqual(layoutSubViewsSpan.context.spanDescription, self.layoutSubviews)
        } else {
            XCTFail("Expected a layoutSubViews span")
        }
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.context.parentSpanId, tracer.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidLayoutSubviews)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            if let blockSpan = self.getStack(tracker).last {
                XCTAssertEqual(blockSpan.context.parentSpanId, tracer.context.spanId)
                XCTAssertEqual(blockSpan.context.spanDescription, self.viewWillAppear)
            } else {
                XCTFail("Expected a span")
            }
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(tracer.isFinished)
        
        let viewAppearingSpan = (Dynamic(transactionSpan).children as [Span]?)!.last!
        XCTAssertEqual(viewAppearingSpan.context.parentSpanId, tracer.context.spanId)
        XCTAssertEqual(viewAppearingSpan.context.spanDescription, self.viewAppearing)
        
        lifecycleEndingMethod(sut, viewController, tracker, callbackExpectation, tracer)

        XCTAssertEqual(finishStatus.rawValue, viewAppearingSpan.context.status.rawValue)

        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 8)
        XCTAssertTrue(tracer.isFinished)
        XCTAssertEqual(finishStatus.rawValue, tracer.context.status.rawValue)

        wait(for: [callbackExpectation], timeout: 0)

        assertTrackerIsEmpty(tracker)
    }
    
    func testTimeMeasurement() {
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
        assertSpanDuration(span: lastSpan, expectedDuration: 1)
        
        sut.viewControllerViewDidLoad(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 3)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 3)
        
        guard let layoutSubViewsSpan = (Dynamic(transactionSpan).children as [Span]?)?.last else {
            XCTFail("Expected a span")
            return
        }
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 2)
        assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 1)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 1)
        
        guard let viewAppearingSpan = (Dynamic(transactionSpan).children as [Span]?)?.last else {
            XCTFail("Expected a span")
            return
        }
        advanceTime(bySeconds: 4)

        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 5)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 5)
        assertSpanDuration(span: viewAppearingSpan, expectedDuration: 4)
        
        assertSpanDuration(span: transactionSpan, expectedDuration: 22)
        
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testTimeMeasurement_SkipLoadView() {
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
        assertSpanDuration(span: lastSpan, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 3)
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 3)
        
        guard let layoutSubViewsSpan = (Dynamic(transactionSpan).children as [Span]?)?.last else {
            XCTFail("Expected a span")
            return
        }
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 2)
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 2)
        assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 1)
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 1)
        
        guard let viewAppearingSpan = (Dynamic(transactionSpan).children as [Span]?)?.last else {
            XCTFail("Expected a span")
            return
        }
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker).last
            self.advanceTime(bySeconds: 5)
        }
        assertSpanDuration(span: lastSpan, expectedDuration: 5)
        assertSpanDuration(span: viewAppearingSpan, expectedDuration: 4)
        
        assertSpanDuration(span: transactionSpan, expectedDuration: 21)

        assertTrackerIsEmpty(tracker)
    }
    
    func testWaitingForCustomSpan() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span?
        
        var lastSpan: Span?
        var customSpanId: SpanId?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker).first
            lastSpan = self.getStack(tracker).last
            customSpanId = tracker.startSpan(withName: self.spanName, operation: self.spanOperation)
        }
        if let lastSpan = lastSpan {
            XCTAssertTrue(lastSpan.isFinished)
        } else {
            XCTFail("Expected a span")
        }
        
        sut.viewControllerViewWillAppear(viewController) {
            //intentionally left empty.
        }
        sut.viewControllerViewDidAppear(viewController) {
            //intentionally left empty.
            //Need to call viewControllerViewDidAppear to finish the transaction.
        }

        if let transactionSpan = transactionSpan, let customSpanId = customSpanId {
            XCTAssertFalse(transactionSpan.isFinished)
            tracker.finishSpan(customSpanId)
            XCTAssertTrue(transactionSpan.isFinished)
        } else {
            XCTFail("Expected a transaction span")
        }

        guard let children = Dynamic(transactionSpan).children.asArray else {
            XCTFail("Expected child spans")
            return
        }
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
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID")
    }
    
    func testOverloadCall() {
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
        
        if let transactionSpan = transactionSpan {
            XCTAssertFalse(transactionSpan.isFinished)
        } else {
            XCTFail("Expected a transaction")
        }
        
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

        if let transactionSpan = transactionSpan {
            XCTAssertFalse(transactionSpan.isFinished)
            XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 2)
        } else {
            XCTFail("Expected a transaction")
        }

        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testLoadView_withUIViewController() {
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
    
    func testSecondLoadView() {
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

        guard let children = Dynamic(transactionSpan).children.asArray else {
            XCTFail("Expected children spans")
            return
        }
        XCTAssertEqual(children.count, 2)
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testMultiplesViewController() {
        let sut = fixture.getSut()
        let firstController = TestViewController()
        let secondController = TestViewController()
        let tracker = fixture.tracker

        var firstTransaction: SentryTracer!
        var secondTransaction: SentryTracer!

        sut.viewControllerViewDidLoad(firstController) {
            firstTransaction = self.getStack(tracker).first as? SentryTracer
        }

        sut.viewControllerViewDidLoad(secondController) {
            secondTransaction = self.getStack(tracker).first as? SentryTracer
        }

        //Callback methods intentionally left blank from now on
        sut.viewControllerViewWillLayoutSubViews(firstController) {
        }

        sut.viewControllerViewWillLayoutSubViews(secondController) {
        }

        sut.viewControllerViewDidLayoutSubViews(firstController) {
        }

        var firstSpanChildren: [Span]? = Dynamic(firstTransaction).children as [Span]?
        XCTAssertEqual(firstSpanChildren?.count, 4)

        sut.viewControllerViewDidLayoutSubViews(secondController) {
        }

        var secondSpanChildren: [Span]? = Dynamic(secondTransaction).children as [Span]?
        XCTAssertEqual(secondSpanChildren?.count, 4)

        sut.viewControllerViewWillAppear(firstController) {
        }

        sut.viewControllerViewWillAppear(secondController) {
        }

        sut.viewControllerViewDidAppear(firstController) {
        }

        firstSpanChildren = Dynamic(firstTransaction).children as [Span]?
        XCTAssertEqual(firstSpanChildren?.count, 7)

        sut.viewControllerViewDidAppear(secondController) {
        }

        secondSpanChildren = Dynamic(secondTransaction).children as [Span]?
        XCTAssertEqual(secondSpanChildren?.count, 7)
    }

    private func assertSpanDuration(span: Span?, expectedDuration: TimeInterval) {
        guard let span = span else {
            XCTFail("Expected a span")
            return
        }
        guard let timestamp = span.timestamp, let startTimestamp = span.startTimestamp else {
            XCTFail("Expected timestamps on the span")
            return
        }
        let duration = timestamp.timeIntervalSince(startTimestamp)
        XCTAssertEqual(duration, expectedDuration)
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
}
#endif
