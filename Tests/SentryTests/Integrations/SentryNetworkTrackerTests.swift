//import XCTest
//
//class SentryNetworkTrackerTests: XCTestCase {
//    
//    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
//    private static let testURL = URL(string: "https://www.domain.com/api")!
//    
//    private class Fixture {
//        static let url = ""
//        let tracker = SentryPerformanceTracker()
//        let sentryTask: URLSessionDataTaskMock
//        let dateProvider = TestCurrentDateProvider()
//        let options: Options
//        
//        init() {
//            options = Options()
//            options.dsn = SentryNetworkTrackerTests.dsnAsString
//            sentryTask = URLSessionDataTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
//        }
//        
//        func getSut() -> SentryNetworkTracker {
//            let result = SentryNetworkTracker.sharedInstance
//            Dynamic(result).tracker = self.tracker
//            
//            return result
//        }
//    }
//
//    private var fixture: Fixture!
//    
//    override func setUp() {
//        super.setUp()
//        fixture = Fixture()
////        CurrentDate.setCurrentDateProvider(fixture.dateProvider)
//    }
//    
//    override func tearDown() {
//        super.tearDown()
////        CurrentDate.setCurrentDateProvider(nil)
//    }
//      
//    func testCaptureCompletion() {
//        let sut = fixture.getSut()
//        let task = createDataTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let spans = getStack(tracker: tracker)
//        let span = spans.first?.value
//                     
//        XCTAssertEqual(spans.count, 1)
//        XCTAssertFalse(span!.isFinished)
//        task.state = .completed
//        XCTAssertTrue(span!.isFinished)
//
//        //Test if it has observers. Nil means no observers
//        XCTAssertNil(task.observationInfo)
//    }
//    
//    func testCaptureDownloadTask() {
//        let sut = fixture.getSut()
//        let task = createDownloadTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let spans = getStack(tracker: tracker)
//        
//        XCTAssertEqual(spans.count, 1)
//        task.state = .completed
//        XCTAssertNil(task.observationInfo)
//    }
//    
//    func testCaptureUploadTask() {
//        let sut = fixture.getSut()
//        let task = createUploadTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let spans = getStack(tracker: tracker)
//        
//        XCTAssertEqual(spans.count, 1)
//        task.state = .completed
//        XCTAssertNil(task.observationInfo)
//    }
//    
//    func testIgnoreStreamTask() {
//        let sut = fixture.getSut()
//        let task = createStreamTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        XCTAssertNil(task.observationInfo)
//        
//        let spans = getStack(tracker: tracker)
//        
//        XCTAssertEqual(spans.count, 0)
//    }
//    
//    func tesIgnoreSentryApi() {
//        let client = TestClient(options: fixture.options)
//        let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: TestSentryCrashAdapter.sharedInstance(), andCurrentDateProvider: fixture.dateProvider)
//        SentrySDK.setCurrentHub(hub)
//        
//        let sut = fixture.getSut()
//        let task = fixture.sentryTask
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        XCTAssertNil(task.observationInfo)
//        
//        let span = getStack(tracker: tracker)
//        XCTAssertEqual(span.count, 0)
//        SentrySDK.setCurrentHub(nil)
//    }
//    
//    func tesCaptureRequestDuration() {
//        let sut = fixture.getSut()
//        let task = createDataTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let span = getStack(tracker: tracker).first!.value
//        
//        advanceTime(bySeconds: 5)
//        
//        XCTAssertFalse(span.isFinished)
//        task.state = .completed
//        XCTAssertTrue(span.isFinished)
//        
//        assertSpanDuration(span: span, expectedDuration: 5)
//    }
//    
//    func testCaptureCancelledRequest() {
//        assertStatus(status: .cancelled, state: .canceling, response: URLResponse())
//    }
//    
//    func testCaptureSuspendedRequest() {
//        assertStatus(status: .aborted, state: .suspended, response: URLResponse())
//    }
//    
//    func testCaptureRequestWithError() {
//        let sut = fixture.getSut()
//        let task = createDataTask()
//        let tracker = fixture.tracker
//        sut.urlSessionTaskResume(task)
//                
//        let spans = getStack(tracker: tracker)
//        let span = spans.first!.value
//        
//        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))
//        task.state = .completed
//        
//        XCTAssertEqual(span.context.status, .unknownError)
//    }
//    
//    func testSpanNameWithGet() {
//        let sut = fixture.getSut()
//        let task = createDataTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let spans = getStack(tracker: tracker)
//        let span = spans.first?.value as? SentryTracer
//        
//        XCTAssertEqual(span!.name, "GET \(SentryNetworkTrackerTests.testURL)")
//    }
//    
//    func testSpanNameWithPost() {
//        let sut = fixture.getSut()
//        let task = createDataTask(method: "POST")
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let spans = getStack(tracker: tracker)
//        let span = spans.first?.value as? SentryTracer
//        
//        XCTAssertEqual(span!.name, "POST \(SentryNetworkTrackerTests.testURL)")
//    }
//    
//    func testCaptureResponses() {
//        assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))
//        assertStatus(status: .undefined, state: .completed, response: createResponse(code: 300))
//        assertStatus(status: .invalidArgument, state: .completed, response: createResponse(code: 400))
//        assertStatus(status: .unauthenticated, state: .completed, response: createResponse(code: 401))
//        assertStatus(status: .permissionDenied, state: .completed, response: createResponse(code: 403))
//        assertStatus(status: .notFound, state: .completed, response: createResponse(code: 404))
//        assertStatus(status: .aborted, state: .completed, response: createResponse(code: 409))
//        assertStatus(status: .resourceExhausted, state: .completed, response: createResponse(code: 429))
//        assertStatus(status: .internalError, state: .completed, response: createResponse(code: 500))
//        assertStatus(status: .unimplemented, state: .completed, response: createResponse(code: 501))
//        assertStatus(status: .unavailable, state: .completed, response: createResponse(code: 503))
//        assertStatus(status: .deadlineExceeded, state: .completed, response: createResponse(code: 504))
//        assertStatus(status: .undefined, state: .completed, response: URLResponse())
//    }
//    
//    func assertStatus(status: SentrySpanStatus, state: URLSessionTask.State, response: URLResponse) {
//        let sut = fixture.getSut()
//        let task = createDataTask()
//        let tracker = fixture.tracker
//        
//        sut.urlSessionTaskResume(task)
//        let span = getStack(tracker: tracker).first!.value
//        
//        task.setResponse(response)
//        
//        task.state = state
//        
//        let httpStatusCode = span.data?["http.status_code"] as? NSNumber
//        if let httpResponse = response as? HTTPURLResponse {
//            XCTAssertEqual(httpResponse.statusCode, httpStatusCode!.intValue)
//        } else {
//            XCTAssertNil(httpStatusCode)
//        }
//                
//        XCTAssertEqual(span.context.status, status)
//        XCTAssertNil(task.observationInfo)
//    }
//    
//    private func createResponse(code: Int) -> URLResponse {
//        return HTTPURLResponse(url: SentryNetworkTrackerTests.testURL, statusCode: code, httpVersion: "1.1", headerFields: nil)!
//    }
//    
//    private func advanceTime(bySeconds: TimeInterval) {
//        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
//    }
//    
//    private func getStack(tracker: SentryPerformanceTracker) -> [SpanId: Span] {
//        let result = Dynamic(tracker).spans as [SpanId: Span]?
//        return result!
//    }
//    
//    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
//        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
//        XCTAssertEqual(duration, expectedDuration)
//    }
//    
//    func createDataTask(method: String = "GET") -> URLSessionDataTaskMock {
//        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
//        request.httpMethod = method
//        return URLSessionDataTaskMock(request: request)
//    }
//    
//    func createDownloadTask(method: String = "GET") -> URLSessionDownloadTaskMock {
//        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
//        request.httpMethod = method
//        return URLSessionDownloadTaskMock(request: request)
//    }
//    
//    func createUploadTask(method: String = "GET") -> URLSessionUploadTaskMock {
//        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
//        request.httpMethod = method
//        return URLSessionUploadTaskMock(request: request)
//    }
//    
//    func createStreamTask(method: String = "GET") -> URLSessionStreamTaskMock {
//        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
//        request.httpMethod = method
//        return URLSessionStreamTaskMock(request: request)
//    }
//}
