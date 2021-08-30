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
        let nsUrlRequest = NSURLRequest(url: SentryNetworkTrackerTests.testURL)
        
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
        
        var mutableUrlRequest: URLRequest {
            return URLRequest(url: SentryNetworkTrackerTests.testURL)
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
        
        assertCompletedSpan(task, span)
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
    
    func testStatusForTaskRunning() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let status = Dynamic(sut).statusForSessionTask(task) as SentrySpanStatus?
        XCTAssertEqual(status, .undefined)
    }
    
    func testSpanRemovedFromAssociatedObject() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?
        
        objc_removeAssociatedObjects(task)
        
        XCTAssertFalse(spans!.first!.isFinished)
        XCTAssertNotNil(task.observationInfo)
        
        task.state = .completed
        XCTAssertNotNil(task.observationInfo)
        XCTAssertFalse(spans!.first!.isFinished)
    }
    
    func testTaskStateChangedForRunning() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?
        task.state = .running
        XCTAssertFalse(spans!.first!.isFinished)
        
        XCTAssertNotNil(task.observationInfo)
        
        task.state = .completed
        XCTAssertNil(task.observationInfo)
        XCTAssertTrue(spans!.first!.isFinished)
    }
    
    func testTaskWithoutCurrentRequest() {
        let request = URLRequest(url: SentryNetworkTrackerTests.testURL)
        let task = URLSessionUnsupportedTaskMock(request: request)
        let span = spanForTask(task: task)

        XCTAssertNil(span)
        XCTAssertNil(task.observationInfo)
    }

    func testObserverForAnotherProperty() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?
        
        task.addObserver(sut, forKeyPath: "error", options: .new, context: nil)
        task.setError(NSError(domain: "TEST_ERROR", code: -1, userInfo: nil))
        XCTAssertFalse(spans!.first!.isFinished)
        
        task.removeObserver(sut, forKeyPath: "error")
        XCTAssertNotNil(task.observationInfo)
        
        task.state = .completed
        XCTAssertNil(task.observationInfo)
        XCTAssertTrue(spans!.first!.isFinished)
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
    
    func testBreadcrumb() {
        assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))
        
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs!.first
        
        XCTAssertEqual(breadcrumb!.category, "http")
        XCTAssertEqual(breadcrumb!.level, .info)
        XCTAssertEqual(breadcrumb!.type, "http")
        XCTAssertEqual(breadcrumbs!.count, 1)
        XCTAssertEqual(breadcrumb!.data!["url"] as! String, SentryNetworkTrackerTests.testURL.absoluteString)
        XCTAssertEqual(breadcrumb!.data!["method"] as! String, "GET")
        XCTAssertEqual(breadcrumb!.data!["status_code"] as! NSNumber, NSNumber(value: 200))
        XCTAssertEqual(breadcrumb!.data!["reason"] as! String, HTTPURLResponse.localizedString(forStatusCode: 200))
        XCTAssertEqual(breadcrumb!.data!["request_body_size"] as! Int64, DATA_BYTES_SENT)
        XCTAssertEqual(breadcrumb!.data!["response_body_size"] as! Int64, DATA_BYTES_RECEIVED)
    }
    
    func testBreadcrumbWithoutSpan() {
        let task = createDataTask()
        let _ = spanForTask(task: task)!
        
        objc_removeAssociatedObjects(task)
        
        task.state = .completed
        
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs!.first
        
        XCTAssertEqual(breadcrumb!.category, "http")
        XCTAssertEqual(breadcrumb!.level, .info)
        XCTAssertEqual(breadcrumb!.type, "http")
        XCTAssertEqual(breadcrumbs!.count, 1)
        XCTAssertEqual(breadcrumb!.data!["url"] as! String, SentryNetworkTrackerTests.testURL.absoluteString)
        XCTAssertEqual(breadcrumb!.data!["method"] as! String, "GET")
    }
    
    func testBreadcrumbNotFound() {
        assertStatus(status: .notFound, state: .completed, response: createResponse(code: 404))
        
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs!.first
        
        XCTAssertEqual(breadcrumb!.data!["status_code"] as! NSNumber, NSNumber(value: 404))
        XCTAssertEqual(breadcrumb!.data!["reason"] as! String, HTTPURLResponse.localizedString(forStatusCode: 404))
    }
    
    func testBreadcrumbWithError() {
        let task = createDataTask()
        let _ = spanForTask(task: task)!
        
        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))
        task.state = .completed
        
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs!.first
        
        XCTAssertEqual(breadcrumb!.category, "http")
        XCTAssertEqual(breadcrumb!.level, .error)
        XCTAssertEqual(breadcrumb!.type, "http")
        XCTAssertEqual(breadcrumbs!.count, 1)
        XCTAssertEqual(breadcrumb!.data!["url"] as! String, SentryNetworkTrackerTests.testURL.absoluteString)
        XCTAssertEqual(breadcrumb!.data!["method"] as! String, "GET")
        XCTAssertNil(breadcrumb!.data!["status_code"])
        XCTAssertNil(breadcrumb!.data!["reason"])
    }
    
    func testBreadcrumbPost() {
        let task = createDataTask(method: "POST")
        let _ = spanForTask(task: task)!
        
        task.state = .completed
        
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs!.first

        XCTAssertEqual(breadcrumb!.data!["method"] as! String, "POST")
    }
    
    func testResumeAfterCompleted_OnlyOneSpanCreated() {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        task.state = .completed
        sut.urlSessionTaskResume(task)

        assertOneSpanCreated(transaction)
    }
    
    func testResumeAfterCancelled_OnlyOneSpanCreated() {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        
        sut.urlSessionTaskResume(task)
        task.state = .canceling
        sut.urlSessionTaskResume(task)

        assertOneSpanCreated(transaction)
    }
    
    // Altough we only run this test above the below specified versions, we exped the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testResumeCalledMultipleTimesConcurrent_OneSpanCreated() {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        
        let queue = DispatchQueue(label: "SentryNetworkTrackerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0...100_000 {
            group.enter()
            queue.async {
                sut.urlSessionTaskResume(task)
                task.state = .completed
                group.leave()
            }
        }
        
        queue.activate()
        group.waitWithTimeout(timeout: 100)
        
        assertOneSpanCreated(transaction)
    }
    
    // Altough we only run this test above the below specified versions, we exped the
    // implementation to be thread safe
    @available(tvOS 10.0, *)
    @available(OSX 10.12, *)
    @available(iOS 10.0, *)
    func testChangeStateMultipleTimesConcurrent_OneSpanFinished() {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        sut.urlSessionTaskResume(task)
        
        let queue = DispatchQueue(label: "SentryNetworkTrackerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0...100_000 {
            group.enter()
            queue.async {
                task.state = .completed
                group.leave()
            }
        }
        
        queue.activate()
        group.waitWithTimeout(timeout: 100)
        
        let spans = Dynamic(transaction).children as [Span]?
        XCTAssertEqual(1, spans?.count)
        let span = spans!.first!
        
        XCTAssertTrue(span.isFinished)
        //Test if it has observers. Nil means no observers
        XCTAssertNil(task.observationInfo)
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
        
        let httpStatusCode = span.tags["http.status_code"] as String?
        
        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual("\(httpResponse.statusCode)", httpStatusCode!)
        } else {
            XCTAssertNil(httpStatusCode)
        }
        
        let path = span.data!["url"] as? String
        let method = span.data!["method"] as? String
        let requestType = span.data!["type"] as? String
        
        XCTAssertEqual(path, task.currentRequest!.url!.path)
        XCTAssertEqual(method, task.currentRequest!.httpMethod)
        XCTAssertEqual(requestType, "fetch")
                
        XCTAssertEqual(span.context.status, status)
        XCTAssertNil(task.observationInfo)
    }
    
    private func assertCompletedSpan(_ task: URLSessionDataTaskMock, _ span: Span) {
        XCTAssertNotNil(span)
        XCTAssertFalse(span.isFinished)
        task.state = .completed
        XCTAssertTrue(span.isFinished)

        //Test if it has observers. Nil means no observers
        XCTAssertNil(task.observationInfo)
    }
    
    private func assertOneSpanCreated(_ transaction: Span) {
        let spans = Dynamic(transaction).children as [Span]?
        XCTAssertEqual(1, spans?.count)
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
}
