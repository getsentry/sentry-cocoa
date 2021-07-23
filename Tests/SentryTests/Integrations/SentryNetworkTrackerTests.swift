import ObjectiveC
import XCTest

class SentryNetworkTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    private static let testURL = URL(string: "https://www.domain.com/api")!
    private static let transactionName = "TestTransaction"
    private static let transactionOperation = "Test"
    
    private class Fixture {
        static let url = ""
        let sentryTask: URLSessionDataTaskMock
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        let scope: Scope
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerTests.dsnAsString
            sentryTask = URLSessionDataTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
            scope = Scope()
        }
        
        func getSut() -> SentryNetworkTracker {
            let result = SentryNetworkTracker.sharedInstance
            result.enable()
            return result
        }
    }

    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.setCurrentHub(TestHub(client: TestClient(options: fixture.options), andScope: fixture.scope))
        CurrentDate.setCurrentDateProvider(fixture.dateProvider)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
      
    func testCaptureCompletion() {
        let task = createDataTask()
        let span = spanForTask(task: task)!
        
        XCTAssertNotNil(span)
        XCTAssertFalse(span.isFinished)
        task.state = .completed
        XCTAssertTrue(span.isFinished)

        //Test if it has observers. Nil means no observers
        XCTAssertNil(task.observationInfo)
    }
    
    func testCaptureDownloadTask() {
        let task = createDownloadTask()
        let span = spanForTask(task: task)
        
        XCTAssertNotNil(span)
        task.state = .completed
        XCTAssertNil(task.observationInfo)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testCaptureUploadTask() {
        let task = createUploadTask()
        let span = spanForTask(task: task)
        
        XCTAssertNotNil(span)
        task.state = .completed
        XCTAssertNil(task.observationInfo)
        XCTAssertTrue(span!.isFinished)
    }
    
    func testIgnoreStreamTask() {
        let task = createStreamTask()
        let span = spanForTask(task: task)
        
        XCTAssertNil(span)
        XCTAssertNil(task.observationInfo)
    }
    
    func testTrackerWithoutTransaction() {
        let sut = fixture.getSut()
        let task = createDataTask()
        sut.urlSessionTaskResume(task)
        XCTAssertNil(task.observationInfo)
        
        XCTAssertNil(fixture.scope.span)
    }

    func testIgnoreSentryApi() {
        let task = fixture.sentryTask
        let span = spanForTask(task: task)
        
        XCTAssertNil(span)
        XCTAssertNil(task.observationInfo)
    }
    
    func testSDKOptionsNil() {
        SentrySDK.setCurrentHub(nil)
        
        let task = fixture.sentryTask
        let span = spanForTask(task: task)
        
        XCTAssertNil(span)
    }
    
    func testDisabledTracker() {
        let sut = fixture.getSut()
        sut.disable()
        let task = createUploadTask()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?
        
        XCTAssertEqual(spans!.count, 0)
    }
    
    func testHTTPRequestAlreadyIntercepted() {
        let task = createInterceptedRequest()
        let span = spanForTask(task: task)
        
        XCTAssertNil(span)
    }
    
    func testCaptureRequestDuration() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let tracer = SentryTracer(transactionContext: TransactionContext(name: SentryNetworkTrackerTests.transactionName,
                                                                         operation: SentryNetworkTrackerTests.transactionOperation),
                                  hub: nil,
                                  waitForChildren: true)
        fixture.scope.span = tracer
        
        sut.urlSessionTaskResume(task)
        tracer.finish()
        
        let spans = Dynamic(tracer).children as [Span]?
        let span = spans!.first!
        
        advanceTime(bySeconds: 5)
        
        XCTAssertFalse(span.isFinished)
        task.state = .completed
        XCTAssertTrue(span.isFinished)
        
        assertSpanDuration(span: span, expectedDuration: 5)
        assertSpanDuration(span: tracer, expectedDuration: 5)
    }
    
    func testCaptureCancelledRequest() {
        assertStatus(status: .cancelled, state: .canceling, response: URLResponse())
    }
    
    func testCaptureSuspendedRequest() {
        assertStatus(status: .aborted, state: .suspended, response: URLResponse())
    }
    
    func testCaptureRequestWithError() {
        let task = createDataTask()
        let span = spanForTask(task: task)!
        
        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))
        task.state = .completed
        
        XCTAssertEqual(span.context.status, .unknownError)
    }
    
    func testSpanDescriptionNameWithGet() {
        let task = createDataTask()
        let span = spanForTask(task: task)!
        
        XCTAssertEqual(span.context.spanDescription, "GET \(SentryNetworkTrackerTests.testURL)")
    }
    
    func testSpanDescriptionNameWithPost() {
        let task = createDataTask(method: "POST")
        let span = spanForTask(task: task)!
        
        XCTAssertEqual(span.context.spanDescription, "POST \(SentryNetworkTrackerTests.testURL)")
    }
    
    func testCaptureResponses() {
        assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))
        assertStatus(status: .undefined, state: .completed, response: createResponse(code: 300))
        assertStatus(status: .invalidArgument, state: .completed, response: createResponse(code: 400))
        assertStatus(status: .unauthenticated, state: .completed, response: createResponse(code: 401))
        assertStatus(status: .permissionDenied, state: .completed, response: createResponse(code: 403))
        assertStatus(status: .notFound, state: .completed, response: createResponse(code: 404))
        assertStatus(status: .aborted, state: .completed, response: createResponse(code: 409))
        assertStatus(status: .resourceExhausted, state: .completed, response: createResponse(code: 429))
        assertStatus(status: .internalError, state: .completed, response: createResponse(code: 500))
        assertStatus(status: .unimplemented, state: .completed, response: createResponse(code: 501))
        assertStatus(status: .unavailable, state: .completed, response: createResponse(code: 503))
        assertStatus(status: .deadlineExceeded, state: .completed, response: createResponse(code: 504))
        assertStatus(status: .undefined, state: .completed, response: URLResponse())
    }
    
    func assertStatus(status: SentrySpanStatus, state: URLSessionTask.State, response: URLResponse) {
        let sut = fixture.getSut()
        let task = createDataTask()
        
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        
        let spans = Dynamic(transaction).children as [Span]?
        let span = spans!.first!
        
        task.setResponse(response)
        
        task.state = state
        
        let httpStatusCode = span.data?["http.status_code"] as? NSNumber
        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual(httpResponse.statusCode, httpStatusCode!.intValue)
        } else {
            XCTAssertNil(httpStatusCode)
        }
                
        XCTAssertEqual(span.context.status, status)
        XCTAssertNil(task.observationInfo)
    }
    
    private func spanForTask(task: URLSessionTask) -> Span? {
        let sut = fixture.getSut()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        
        let spans = Dynamic(transaction).children as [Span]?
        return spans?.first
    }
    
    private func startTransaction() -> Span {
        return SentrySDK.startTransaction(name: SentryNetworkTrackerTests.transactionName, operation: SentryNetworkTrackerTests.transactionOperation, bindToScope: true)
    }
    
    private func createResponse(code: Int) -> URLResponse {
        return HTTPURLResponse(url: SentryNetworkTrackerTests.testURL, statusCode: code, httpVersion: "1.1", headerFields: nil)!
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
        
    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) {
        let duration = span.timestamp!.timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
    
    func createDataTask(method: String = "GET") -> URLSessionDataTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
        request.httpMethod = method
        return URLSessionDataTaskMock(request: request)
    }
    
    func createDownloadTask(method: String = "GET") -> URLSessionDownloadTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
        request.httpMethod = method
        return URLSessionDownloadTaskMock(request: request)
    }
    
    func createUploadTask(method: String = "GET") -> URLSessionUploadTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
        request.httpMethod = method
        return URLSessionUploadTaskMock(request: request)
    }
    
    func createStreamTask(method: String = "GET") -> URLSessionStreamTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.testURL)
        request.httpMethod = method
        return URLSessionStreamTaskMock(request: request)
    }

    private func createInterceptedRequest() -> URLSessionDownloadTaskMock {
        let request = NSMutableURLRequest(url: SentryNetworkTrackerTests.testURL)
        URLProtocol.setProperty(true, forKey: SENTRY_INTERCEPTED_REQUEST, in: request)
        request.httpMethod = "GET"
        return URLSessionDownloadTaskMock(request: request as URLRequest)
    }
}
