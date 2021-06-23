import XCTest

class SentryNetworkTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    private static let testURL = URL(string: "https://www.domain.com/api")!
    
    private class Fixture {
        static let url = ""
        let tracker = SentryPerformanceTracker()
        let sentryTask: URLSessionTaskMock
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        
        init() {
            CurrentDate.setCurrentDateProvider(dateProvider)
            
            options = Options()
            options.dsn = SentryNetworkTrackerTests.dsnAsString
            sentryTask = URLSessionTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
        }
        
        func getSut() -> SentryNetworkTracker {
            let result = SentryNetworkTracker.sharedInstance
            Dynamic(result).tracker = self.tracker
            
            return result
        }
        
        func createTask() -> URLSessionTaskMock {
            return URLSessionTaskMock(request: URLRequest(url: SentryNetworkTrackerTests.testURL))
        }
    }

    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testCaptureCompletion() {
        let sut = fixture.getSut()
        let task = fixture.createTask()
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
        let task = fixture.createTask()
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
    
    func testCaptureCanceledRequest() {
        assertStatusForTaskStateAndResponse(status: .cancelled, state: .canceling, response: URLResponse())
    }
    
    func testCaptureSuspendedRequest() {
        assertStatusForTaskStateAndResponse(status: .cancelled, state: .suspended, response: URLResponse())
    }
    
    func testCaptureResponses() {
        assertStatusForTaskStateAndResponse(status: .ok, state: .completed, response: createResponse(code: 200))
        assertStatusForTaskStateAndResponse(status: .invalidArgument, state: .completed, response: createResponse(code: 400))
        assertStatusForTaskStateAndResponse(status: .unauthenticated, state: .completed, response: createResponse(code: 401))
        assertStatusForTaskStateAndResponse(status: .permissionDenied, state: .completed, response: createResponse(code: 403))
        assertStatusForTaskStateAndResponse(status: .notFound, state: .completed, response: createResponse(code: 404))
        assertStatusForTaskStateAndResponse(status: .cancelled, state: .completed, response: createResponse(code: 409))
        assertStatusForTaskStateAndResponse(status: .resourceExhausted, state: .completed, response: createResponse(code: 429))
        assertStatusForTaskStateAndResponse(status: .internalError, state: .completed, response: createResponse(code: 500))
        assertStatusForTaskStateAndResponse(status: .unimplemented, state: .completed, response: createResponse(code: 501))
        assertStatusForTaskStateAndResponse(status: .unavailable, state: .completed, response: createResponse(code: 503))
        assertStatusForTaskStateAndResponse(status: .deadlineExceeded, state: .completed, response: createResponse(code: 504))
    }
      
    func assertStatusForTaskStateAndResponse(status: SentrySpanStatus, state: URLSessionTask.State, response: URLResponse) {
        let sut = fixture.getSut()
        let task = fixture.createTask()
        let tracker = fixture.tracker
        
        sut.urlSessionTaskResume(task)
        let span = getStack(tracker: tracker).first!.value
        
        task.setResponse(response)
        task.state = state
        
        XCTAssertEqual(span.context.status, status)
    }
    
    private func createResponse(code: Int) -> URLResponse {
        return HTTPURLResponse(url: SentryNetworkTrackerTests.testURL, statusCode: code, httpVersion: "1.1", headerFields: nil)!
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
