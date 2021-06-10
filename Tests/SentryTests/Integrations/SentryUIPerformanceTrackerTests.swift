import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIPerformanceTrackerTests: XCTestCase {

    private class Fixture {
        let viewController = UIViewController()
        let tracker = SentryPerformanceTracker()
        let dateProvider = TestCurrentDateProvider()
        
        var viewControllerName: String!
        let loadView = "loadView"
        let viewWillLoad = "viewWillLoad"
        let viewDidLoad = "viewDidLoad"
        let viewWillAppear = "viewWillAppear"
        let viewDidAppear = "viewDidAppear"
        let viewWillLayoutSubviews = "viewWillLayoutSubviews"
        let viewDidLayoutSubviews = "viewDidLayoutSubviews"
        let layoutSubviews = "layoutSubViews"
        let spanName = "spanName"
        let spanOperation = "spanOperation"
        
        func getSut() -> SentryUIPerformanceTracker {
            CurrentDate.setCurrentDateProvider(dateProvider)
            
            viewControllerName = SentryUIViewControllerSanitizer.sanitizeViewControllerName(viewController)
        
            let result = SentryUIPerformanceTracker.shared
            Dynamic(result).tracker = self.tracker
            
            return result
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testUILifeCycle() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        sut.viewControllerLoadView(viewController) {
            let spans = self.getStack(tracker: tracker)
            transactionSpan = spans.first
            
            let blockSpan = spans.last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.loadView)
        }
        XCTAssertEqual((transactionSpan as! SentryTracer?)!.name, fixture.viewControllerName)
        XCTAssertFalse(transactionSpan.isFinished)

        sut.viewControllerViewDidLoad(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.viewDidLoad)
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.viewWillLayoutSubviews)
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        let layoutSubViewsSpan = self.getStack(tracker: tracker).last!
        XCTAssertEqual(layoutSubViewsSpan.context.parentSpanId, transactionSpan.context.spanId)
        XCTAssertEqual(layoutSubViewsSpan.context.spanDescription, self.fixture.layoutSubviews)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.viewDidLayoutSubviews)
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewWillAppear(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.viewWillAppear)
        }
        XCTAssertFalse(transactionSpan.isFinished)
        
        sut.viewControllerViewDidAppear(viewController) {
            let blockSpan = self.getStack(tracker: tracker).last!
            XCTAssertEqual(blockSpan.context.parentSpanId, transactionSpan.context.spanId)
            XCTAssertEqual(blockSpan.context.spanDescription, self.fixture.viewDidAppear)
        }

        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 7)
        XCTAssertTrue(transactionSpan.isFinished)
    }
    
    func testTimeMeasurement() {
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker
        var transactionSpan: Span!
        
        var date = Date(timeIntervalSince1970: 0)
        
        fixture.dateProvider.setDate(date: date)
        var lastSpan: Span?
        
        sut.viewControllerLoadView(viewController) {
            transactionSpan = self.getStack(tracker: tracker).first
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(1)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 1)
        
        sut.viewControllerViewDidLoad(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(2)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        
        sut.viewControllerViewWillLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(3)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 3)
        
        let layoutSubViewsSpan = self.getStack(tracker: tracker).last!
        date = date.addingTimeInterval(4)
        self.fixture.dateProvider.setDate(date: date)
        
        sut.viewControllerViewDidLayoutSubViews(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(2)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 2)
        assertSpanDuration(span: layoutSubViewsSpan, expectedDuration: 4)
        
        sut.viewControllerViewWillAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(1)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 1)
        
        sut.viewControllerViewDidAppear(viewController) {
            lastSpan = self.getStack(tracker: tracker).last!
            date = date.addingTimeInterval(5)
            self.fixture.dateProvider.setDate(date: date)
        }
        assertSpanDuration(span: lastSpan!, expectedDuration: 5)
        
        assertSpanDuration(span: transactionSpan, expectedDuration: 18)
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
            customSpanId = tracker.startSpan(withName: self.fixture.spanName, operation: self.fixture.spanOperation)
        }
        XCTAssertTrue(lastSpan!.isFinished)
        
        sut.viewControllerViewDidAppear(viewController) {
            
        }
        
        XCTAssertFalse(transactionSpan.isFinished)
        tracker.finishSpan(customSpanId!)
        XCTAssertTrue(transactionSpan.isFinished)
        XCTAssertEqual(Dynamic(transactionSpan).children.asArray!.count, 3)
    }
    
    func testSkipLoadView() {
        //Skipping loadView prevent the tracker from creating the view controller transaction and no span is created after this.
        
        let sut = fixture.getSut()
        let viewController = fixture.viewController
        let tracker = fixture.tracker

        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        sut.viewControllerViewDidLoad(viewController) {
            XCTAssertTrue(self.getStack(tracker: tracker).isEmpty)
        }
        XCTAssertTrue(getStack(tracker: tracker).isEmpty)
        
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
    
    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [Span] {
        let result = Dynamic(tracker).activeStack as [Span]?
        return result!
    }
    
}
#endif
