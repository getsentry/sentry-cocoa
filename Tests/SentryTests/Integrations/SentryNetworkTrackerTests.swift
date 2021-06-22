import XCTest

class SentryNetworkTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    private class Fixture {
        static let url = ""
        let tracker = SentryPerformanceTracker()
        let task = URLSessionTaskMock(request: URLRequest(url: URL(string: "https://www.domain.com/api")!))
        let sentryTask: URLSessionTaskMock
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerTests.dsnAsString
            sentryTask = URLSessionTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
        }
        
        func getSut() -> SentryNetworkTracker {
            CurrentDate.setCurrentDateProvider(dateProvider)
            
            let result = SentryNetworkTracker.sharedInstance
            Dynamic(result).tracker = self.tracker
            
            return result
        }
    }

    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testCaptureCompletion() {
        let sut = fixture.getSut()
        let task = fixture.task
        let tracker = fixture.tracker
        
        sut.urlSessionTaskResume(task)
        let spans = getStack(tracker: tracker)
        let span = spans.first?.value
        
        XCTAssertEqual(spans.count, 1)
        XCTAssertFalse(span!.isFinished)
        task.state = .completed
        XCTAssertTrue(span!.isFinished)
    }
    
    func testIgnoreSentryApi() {
        SentrySDK.start(options: fixture.options)
        let sut = fixture.getSut()
        let task = fixture.sentryTask
        let tracker = fixture.tracker
        
        sut.urlSessionTaskResume(task)
        let span = getStack(tracker: tracker)
        XCTAssertEqual(span.count, 0)
    }
    
    func testCaptureRequestDuration() {
        let sut = fixture.getSut()
        let task = fixture.task
        let tracker = fixture.tracker
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 0))
        
        sut.urlSessionTaskResume(task)
        let span = getStack(tracker: tracker).first!.value
        
        advanceTime(bySeconds: 5)
        
        XCTAssertFalse(span.isFinished)
        task.state = .completed
        XCTAssertTrue(span.isFinished)
        
        assertSpanDuration(span: span, expectedDuration: 5)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
    
    private func getStack(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
        let result = Dynamic(tracker).spans as [SpanId: Span]?
        return result!
    }
    
    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
}
