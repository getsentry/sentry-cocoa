import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIPerformanceTrackerTests: XCTestCase {

    let loadView = "loadView"
    let viewWillLoad = "viewWillLoad"
    let viewDidLoad = "viewDidLoad"
    let viewWillAppear = "viewWillAppear"
    let viewAppearing = "viewAppearing"
    let viewDidAppear = "viewDidAppear"
    let viewWillLayoutSubviews = "viewWillLayoutSubviews"
    let viewDidLayoutSubviews = "viewDidLayoutSubviews"
    let layoutSubviews = "layoutSubViews"
    let spanName = "spanName"
    let spanOperation = "spanOperation"
    
    private class Fixture {
        let viewController = UIViewController()
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
    }
    
    func testUILifeCycle() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 6
        
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker: tracker)
            transactionSpan = spans.first
            
            let blockSpan = spans.last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.loadView)
            callbackExpectation.fulfill()
        }
        XCTAssertEqual((transactionSpan as! SentryTracer?)!.name, fixture.viewControllerName)
        XCTAssertFalse(transactionSpan.isFinished)

        sut.viewControllerViewDidLoad(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidLoad)
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.viewWillLayoutSubviews)
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        let layoutSubViewsSpan = self.getStack(tracker: tracker).last!
        XCTAssertEqual(layoutSubViewsSpan.context.parentSpanId, transactionSpan.context.spanId)
        XCTAssertEqual(layoutSubViewsSpan.context.spanDescription, self.layoutSubviews)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidLayoutSubviews)
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.viewWillAppear)
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        let viewAppearingSpan = self.getStack(tracker: tracker).last!
        XCTAssertEqual(viewAppearingSpan.context.parentSpanId, transactionSpan.context.spanId)
        XCTAssertEqual(viewAppearingSpan.context.spanDescription, self.viewAppearing)
        
        sut.viewControllerViewDidAppear(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.viewDidAppear)
            callbackExpectation.fulfill()
        }

        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 8)
        XCTAssertTrue(transactionSpan.isFinished)
        
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testTimeMeasurement() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 6
                
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 0))
        var lastSpan: Span?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker: tracker).first
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 1)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 1)
        
        sut.viewControllerViewDidLoad(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 3)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 3)
        
        let layoutSubViewsSpan = self.getStack(tracker: tracker).last!
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 2)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 1)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 1)
        
        let viewAppearingSpan = self.getStack(tracker: tracker).last!
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 5)
            callbackExpectation.fulfill()
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 5)
        assertSpanDuration(span: viewAppearingSpan, expectedDuration: 4)
        
        assertSpanDuration(span: transactionSpan, expectedDuration: 22)
        
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testTimeMeasurement_SkipLoadView() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
                
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 0))
        var lastSpan: Span?
        
        sut.viewControllerViewDidLoad(viewController) {
            transactionSpan = self.getStack(tracker: tracker).first
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 2)

        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 3)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 3)
        
        let layoutSubViewsSpan = self.getStack(tracker: tracker).last!
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 2)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 1)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 1)
        
        let viewAppearingSpan = self.getStack(tracker: tracker).last!
        advanceTime(bySeconds: 4)
        
        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            self.advanceTime(bySeconds: 5)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 5)
        assertSpanDuration(span: viewAppearingSpan, expectedDuration: 4)
        
        assertSpanDuration(span: transactionSpan, expectedDuration: 21)
    }
    
    func testWaitingForCustomSpan() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        var lastSpan: Span?
        var customSpanId: SpanId?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker: tracker).first
            lastSpan = self.getStack(tracker: tracker).last
            customSpanId = tracker.startSpan(withName: self.spanName, operation: self.spanOperation)
        }
        XCTAssertTrue(lastSpan!.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            //intentionally left empty.
        }
        sut.viewControllerViewDidAppear(viewController) {
            //intentionally left empty.
            //Need to call viewControllerViewDidAppear to finish the transaction.
        }
        
        XCTAssertFalse(transactionSpan.isFinished)
        tracker.finishSpan(customSpanId!)
        XCTAssertTrue(transactionSpan.isFinished)
        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 5)
    }
    
    func testSkipLoadViewAndViewDidLoad() {
        //Skipping loadView prevent the tracker from creating the view controller transaction and no span is created after this.
        
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            XCTAssertTrue(self.getStack(tracker: tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            XCTAssertTrue(self.getStack(tracker: tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        
        sut.viewControllerViewWillAppear(viewController) {
            XCTAssertTrue(self.getStack(tracker: tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        
        sut.viewControllerViewDidAppear(viewController) {
            XCTAssertTrue(self.getStack(tracker: tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
    }
    
    func testSpanAssociatedConstants() {
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_SPAN_ID")
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_LAYOUTSUBVIEW_SPAN_ID")
        XCTAssertEqual(SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID, "SENTRY_UI_PERFORMANCE_TRACKER_VIEWAPPEARING_SPAN_ID")
        XCTAssertEqual(SENTRY_VIEWCONTROLLER_RENDERING_OPERATION, "ui.load")
    }
    
    func testOverloadCall() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 3
        
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        //we need loadView to start the tracking
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker: tracker)
            transactionSpan = spans.first
            
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewDidLoad(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            
            //this is the same as calling super.viewDidLoad in a custom class sub class
            sut.viewControllerViewDidLoad(viewController) {
                let innerblockSpan = self.getStack(tracker: tracker).last!
                XCTAssertTrue(innerblockSpan === blockSpan)
                
                callbackExpectation.fulfill()
            }
            
            callbackExpectation.fulfill()
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 2)
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    func testSecondLoadView() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        let callbackExpectation = expectation(description: "Callback Expectation")
        callbackExpectation.expectedFulfillmentCount = 2
        
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker: tracker)
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
               
        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 2)
        wait(for: [callbackExpectation], timeout: 0)
    }
    
    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeStack as [Span]?
        return result!
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
}
#endif
