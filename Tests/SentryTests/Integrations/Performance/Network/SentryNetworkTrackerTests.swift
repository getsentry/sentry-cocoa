import ObjectiveC
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable file_length
class SentryNetworkTrackerTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    private static let testUrl = "https://www.domain.com/api"
    private static let fullUrl = URL(string: "https://www.domain.com/api?query=value&query2=value2#fragment")!
    private static let transactionName = "TestTransaction"
    private static let transactionOperation = "Test"
    private static let origin = "auto.http.ns_url_session"

    private class Fixture {
        static let url = ""
        let sentryTask: URLSessionDataTaskMock
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        let scope: Scope
        let nsUrlRequest = NSMutableURLRequest(url: SentryNetworkTrackerTests.fullUrl)
        let client: TestClient!
        let hub: TestHub!
        let securityHeader = [ "X-FORWARDED-FOR": "value",
                               "AUTHORIZATION": "value",
                               "COOKIE": "value",
                               "SET-COOKIE": "value",
                               "X-API-KEY": "value",
                               "X-REAL-IP": "value",
                               "REMOTE-ADDR": "value",
                               "FORWARDED": "value",
                               "PROXY-AUTHORIZATION": "value",
                               "X-CSRF-TOKEN": "value",
                               "X-CSRFTOKEN": "value",
                               "X-XSRF-TOKEN": "value",
                               "VALID_HEADER": "value" ]

        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerTests.dsnAsString
            sentryTask = URLSessionDataTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
            scope = Scope()
            client = TestClient(options: options)
            hub = TestHub(client: client, andScope: scope)
        }

        func getSut() -> SentryNetworkTracker {
            let result = SentryNetworkTracker.sharedInstance
            result.enableNetworkTracking()
            result.enableNetworkBreadcrumbs()
            result.enableCaptureFailedRequests()
            result.enableGraphQLOperationTracking()
            return result
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()

        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.options)
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.dateProvider
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testCaptureCompletion() throws {
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        try assertCompletedSpan(task, span)
    }

    func test_CallResumeTwice_OneSpan() {
        let task = createDataTask()

        let sut = fixture.getSut()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        sut.urlSessionTaskResume(task)

        let spans = Dynamic(transaction).children as [Span]?

        XCTAssertEqual(spans?.count, 1)
    }

    func test_noURL() {
        let task = URLSessionDataTaskMock()
        let span = spanForTask(task: task)
        XCTAssertNil(span)
    }

    func test_NoTransaction() {
        let task = createDataTask()

        let sut = fixture.getSut()
        sut.urlSessionTaskResume(task)
        let span = objc_getAssociatedObject(task, SENTRY_NETWORK_REQUEST_TRACKER_SPAN)

        XCTAssertNil(span)
    }

    func testCaptureDownloadTask() throws {
        let task = createDownloadTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        XCTAssertNotNil(span)
        try setTaskState(task, state: .completed)
        XCTAssertTrue(span.isFinished)
    }

    func testCaptureUploadTask() throws {
        let task = createUploadTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        XCTAssertNotNil(span)
        try setTaskState(task, state: .completed)
        XCTAssertTrue(span.isFinished)
    }

    func testIgnoreStreamTask() {
        let task = createStreamTask()
        let span = spanForTask(task: task)
        //Ignored during resume
        XCTAssertNil(span)

        fixture.getSut().urlSessionTask(task, setState: .completed)
        //ignored during state change
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumb = breadcrumbs?.first
        XCTAssertNil(breadcrumb)
    }

    func testIgnoreSentryApi() {
        let task = fixture.sentryTask
        let span = spanForTask(task: task)

        XCTAssertNil(span)
        XCTAssertNil(task.observationInfo)
    }

    func testSDKOptionsNil() {
        SentrySDKInternal.setCurrentHub(nil)

        let task = fixture.sentryTask
        let span = spanForTask(task: task)

        XCTAssertNil(span)
    }

    func testDisabledTracker() throws {
        let sut = fixture.getSut()
        sut.disable()
        let task = createUploadTask()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?

        XCTAssertEqual(try XCTUnwrap(spans).count, 0)
    }

    func testFinishedSpan() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let tracer = SentryTracer(transactionContext: TransactionContext(name: SentryNetworkTrackerTests.transactionName,
                                                                         operation: SentryNetworkTrackerTests.transactionOperation),
                                  hub: nil,
                                  configuration: SentryTracerConfiguration(block: { $0.waitForChildren = true }))

        tracer.finish()

        fixture.scope.span = tracer

        sut.urlSessionTaskResume(task)

        let spans = Dynamic(tracer).children as [Span]?
        XCTAssertEqual(spans?.count, 0)
    }

    func testCaptureRequestDuration() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let tracer = SentryTracer(transactionContext: TransactionContext(name: SentryNetworkTrackerTests.transactionName,
                                                                         operation: SentryNetworkTrackerTests.transactionOperation),
                                  hub: nil, configuration: SentryTracerConfiguration(block: { $0.waitForChildren = true }))
        fixture.scope.span = tracer

        sut.urlSessionTaskResume(task)
        tracer.finish()

        let spans = Dynamic(tracer).children as [Span]?
        let span = try XCTUnwrap(spans?.first)

        advanceTime(bySeconds: 5)

        XCTAssertFalse(span.isFinished)
        try setTaskState(task, state: .completed)
        XCTAssertTrue(span.isFinished)

        try assertSpanDuration(span: span, expectedDuration: 5)
        try assertSpanDuration(span: tracer, expectedDuration: 5)
    }

    func testCaptureCancelledRequest() throws {
        try assertStatus(status: .cancelled, state: .canceling, response: URLResponse())
    }

    func testCaptureSuspendedRequest() throws {
        try assertStatus(status: .aborted, state: .suspended, response: URLResponse())
    }

    func testCaptureRequestWithError() throws {
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))
        try setTaskState(task, state: .completed)

        XCTAssertEqual(span.status, .unknownError)
    }

    func testSpanDescriptionNameWithGet() throws {
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        XCTAssertEqual(span.spanDescription, "GET \(SentryNetworkTrackerTests.testUrl)")
        XCTAssertEqual(SentryNetworkTrackerTests.origin, span.origin)
    }

    func testSpanDescriptionNameWithPost() throws {
        let task = createDataTask(method: "POST")
        let span = try XCTUnwrap(spanForTask(task: task))

        XCTAssertEqual(span.spanDescription, "POST \(SentryNetworkTrackerTests.testUrl)")
        XCTAssertEqual(SentryNetworkTrackerTests.origin, span.origin)
    }

    func testStatusForTaskRunning() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let status = Dynamic(sut).statusForSessionTask(task, state: URLSessionTask.State.running) as SentrySpanStatus?
        XCTAssertEqual(status, .undefined)
    }

    func testSpanRemovedFromAssociatedObject() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?

        objc_removeAssociatedObjects(task)

        XCTAssertFalse(try XCTUnwrap(spans?.first?.isFinished))

        try setTaskState(task, state: .completed)
        XCTAssertFalse(try XCTUnwrap(spans?.first?.isFinished))
    }

    func testTaskStateChangedForRunning() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?
        task.state = .running
        XCTAssertFalse(try XCTUnwrap(spans?.first?.isFinished))

        try setTaskState(task, state: .completed)
        XCTAssertTrue(try XCTUnwrap(spans?.first?.isFinished))
    }

    func testTaskWithoutCurrentRequest() {
        let request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        let task = URLSessionUnsupportedTaskMock(request: request)
        let span = spanForTask(task: task)

        XCTAssertNil(span)
        XCTAssertNil(task.observationInfo)
    }

    func testObserverForAnotherProperty() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        let spans = Dynamic(transaction).children as [Span]?

        task.setError(NSError(domain: "TEST_ERROR", code: -1, userInfo: nil))
        sut.urlSessionTask(task, setState: .running)
        XCTAssertFalse(try XCTUnwrap(spans?.first).isFinished)

        try setTaskState(task, state: .completed)
        XCTAssertTrue(try XCTUnwrap(spans?.first).isFinished)
    }

    func testCaptureResponses() throws {
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))
        try assertStatus(status: .undefined, state: .completed, response: createResponse(code: 300))
        try assertStatus(status: .invalidArgument, state: .completed, response: createResponse(code: 400))
        try assertStatus(status: .unauthenticated, state: .completed, response: createResponse(code: 401))
        try assertStatus(status: .permissionDenied, state: .completed, response: createResponse(code: 403))
        try assertStatus(status: .notFound, state: .completed, response: createResponse(code: 404))
        try assertStatus(status: .aborted, state: .completed, response: createResponse(code: 409))
        try assertStatus(status: .resourceExhausted, state: .completed, response: createResponse(code: 429))
        try assertStatus(status: .internalError, state: .completed, response: createResponse(code: 500))
        try assertStatus(status: .unimplemented, state: .completed, response: createResponse(code: 501))
        try assertStatus(status: .unavailable, state: .completed, response: createResponse(code: 503))
        try assertStatus(status: .deadlineExceeded, state: .completed, response: createResponse(code: 504))
        try assertStatus(status: .undefined, state: .completed, response: URLResponse())
    }

    func testBreadcrumb() throws {
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .info)
        XCTAssertEqual(breadcrumb.type, "http")
        XCTAssertEqual(breadcrumbs.count, 1)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["url"] as? String), SentryNetworkTrackerTests.testUrl)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "GET")
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["status_code"] as? NSNumber), NSNumber(value: 200))
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["reason"] as? String), HTTPURLResponse.localizedString(forStatusCode: 200))
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["request_body_size"] as? Int64), DATA_BYTES_SENT)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["response_body_size"] as? Int64), DATA_BYTES_RECEIVED)
        XCTAssertEqual(breadcrumb.data?["http.query"] as? String, "query=value&query2=value2")
        XCTAssertEqual(breadcrumb.data?["http.fragment"] as? String, "fragment")
        XCTAssertNotNil(breadcrumb.data?["request_start"])
        XCTAssertTrue(breadcrumb.data?["request_start"] is Date)
        XCTAssertNil(breadcrumb.data?["graphql_operation_name"])
    }

    func testNetworkBreadcrumbForSessionReplay() throws {
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?

        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = try XCTUnwrap(breadcrumbs?.first, "No breadcrumbs")

        let result = try XCTUnwrap(sut.convert(from: crumb) as? SentryRRWebSpanEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        let start = try XCTUnwrap(crumb.data?["request_start"] as? Date)

        XCTAssertEqual(result.timestamp, start)
        XCTAssertEqual(crumbData["tag"] as? String, "performanceSpan")
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api")
        XCTAssertEqual(payload["op"] as? String, "resource.http")
        XCTAssertEqual(payload["startTimestamp"] as? Double, start.timeIntervalSince1970)
        XCTAssertEqual(payload["endTimestamp"] as? Double, crumb.timestamp?.timeIntervalSince1970)
        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertEqual(payloadData["query"] as? String, "query=value&query2=value2")
        XCTAssertEqual(payloadData["fragment"] as? String, "fragment")
    }

    func testNetworkBreadcrumbForSessionReplay_WithoutNetworkTracing() throws {
        let tracer = fixture.getSut()
        tracer.disable()
        tracer.enableNetworkBreadcrumbs()
        let task = createDataTask()
        tracer.urlSessionTaskResume(task)
        task.setResponse(try createResponse(code: 200))
        tracer.urlSessionTask(task, setState: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?

        let sut = SentrySRDefaultBreadcrumbConverter()
        let crumb = try XCTUnwrap(breadcrumbs?.first, "No breadcrumbs")

        let result = try XCTUnwrap(sut.convert(from: crumb)  as? SentryRRWebSpanEvent)

        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        let start = try XCTUnwrap(crumb.data?["request_start"] as? Date)

        XCTAssertEqual(result.timestamp, start)
        XCTAssertEqual(crumbData["tag"] as? String, "performanceSpan")
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api")
        XCTAssertEqual(payload["op"] as? String, "resource.http")
        XCTAssertEqual(payload["startTimestamp"] as? Double, start.timeIntervalSince1970)
        XCTAssertEqual(payload["endTimestamp"] as? Double, crumb.timestamp?.timeIntervalSince1970)
        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertEqual(payloadData["query"] as? String, "query=value&query2=value2")
        XCTAssertEqual(payloadData["fragment"] as? String, "fragment")
    }

    func testBreadcrumb_GraphQLEnabled() throws {
        let body = """
        {
            "operationName": "someOperationName",
            "variables":{"a": 1},
            "query":"query someOperationName {\\n  someField\\n}\\n"
        }
        """
        fixture.nsUrlRequest.httpBody = body.data(using: .utf8)
        fixture.nsUrlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        XCTAssertEqual(breadcrumb.data?["graphql_operation_name"] as? String, "someOperationName")
    }

    func testBreadcrumb_GraphQLEnabledInvalidData() throws {
        let body = """
        [
            {"message": "arrays are valid json"}
        ]
        """
        fixture.nsUrlRequest.httpBody = body.data(using: .utf8)
        fixture.nsUrlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200))

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        XCTAssertNil(breadcrumb.data?["graphql_operation_name"])
    }

    func testNoBreadcrumb_DisablingBreadcrumb() throws {
        try assertStatus(status: .ok, state: .completed, response: createResponse(code: 200)) {
            $0.disable()
            $0.enableNetworkTracking()
        }

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(breadcrumbs?.count, 0)
    }

    func testBreadcrumb_DisablingNetworkTracking() throws {
        let sut = fixture.getSut()
        let task = createDataTask()

        sut.urlSessionTaskResume(task)
        task.setResponse(try createResponse(code: 200))

        sut.urlSessionTask(task, setState: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(breadcrumbs?.count, 1)

        let breadcrumb = try XCTUnwrap(breadcrumbs?.first)
        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .info)
        XCTAssertEqual(breadcrumb.type, "http")
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["url"] as? String), SentryNetworkTrackerTests.testUrl)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "GET")
    }

    func testBreadcrumbWithoutSpan() throws {
        let task = createDataTask()
        let _ = try XCTUnwrap(spanForTask(task: task))

        objc_removeAssociatedObjects(task)

        try setTaskState(task, state: .completed)

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .info)
        XCTAssertEqual(breadcrumb.type, "http")
        XCTAssertEqual(breadcrumbs.count, 1)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["url"] as? String), SentryNetworkTrackerTests.testUrl)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "GET")
    }

    func testNoDuplicatedBreadcrumbs() throws {
        let task = createDataTask()
        let _ = try XCTUnwrap(spanForTask(task: task))

        objc_removeAssociatedObjects(task)

        try setTaskState(task, state: .completed)
        try setTaskState(task, state: .running)
        try setTaskState(task, state: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let amount = breadcrumbs?.count ?? 0

        XCTAssertEqual(amount, 1)
    }

    func testWhenNoSpan_RemoveObserver() throws {
        let task = createDataTask()
        let _ = try XCTUnwrap(spanForTask(task: task))

        objc_removeAssociatedObjects(task)

        try setTaskState(task, state: .completed)
        try setTaskState(task, state: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(1, breadcrumbs?.count)
    }

    func testBreadcrumbNotFound() throws {
        try assertStatus(status: .notFound, state: .completed, response: createResponse(code: 404))

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["status_code"] as? NSNumber), NSNumber(value: 404))
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["reason"] as? String), HTTPURLResponse.localizedString(forStatusCode: 404))
    }

    func testBreadcrumbWithError_AndPerformanceTrackingNotEnabled() throws {
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        let _ = try XCTUnwrap(spanForTask(task: task))

        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))

        try setTaskState(task, state: .completed)

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .error)
        XCTAssertEqual(breadcrumb.type, "http")
        XCTAssertEqual(breadcrumbs.count, 1)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["url"] as? String), SentryNetworkTrackerTests.testUrl)
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "GET")
        XCTAssertNil(breadcrumb.data?["status_code"])
        XCTAssertNil(breadcrumb.data?["reason"])
    }

    func testBreadcrumbPost() throws {
        let task = createDataTask(method: "POST")
        let _ = try XCTUnwrap(spanForTask(task: task))

        try setTaskState(task, state: .completed)

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "POST")
    }

    func test_NoBreadcrumb_forSentryAPI() throws {
        let sut = fixture.getSut()
        let task = fixture.sentryTask

        try setTaskState(task, state: .running)
        sut.urlSessionTask(task, setState: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(breadcrumbs?.count, 0)
    }

    func test_NoBreadcrumb_WithoutURL() throws {
        let sut = fixture.getSut()
        let task = URLSessionDataTaskMock()

        try setTaskState(task, state: .running)
        sut.urlSessionTask(task, setState: .completed)

        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(breadcrumbs?.count, 0)
    }
    
    func test_Breadcrumb_HTTP200_HasLevelInfo() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 200))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .info)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(200, data["status_code"] as? Int)
        XCTAssertEqual("no error", data["reason"] as? String)
    }
    
    func test_Breadcrumb_HTTP399_HasLevelInfo() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 399))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .info)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(399, data["status_code"] as? Int)
        XCTAssertEqual("redirected", data["reason"] as? String)
    }
    
    func test_Breadcrumb_HTTP400_HasLevelWarning() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 400))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .warning)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(400, data["status_code"] as? Int)
        XCTAssertEqual("bad request", data["reason"] as? String)
    }
    
    func test_Breadcrumb_HTTP499_HasLevelWarning() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 499))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .warning)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(499, data["status_code"] as? Int)
        XCTAssertEqual("client error", data["reason"] as? String)
    }
    
    func testBreadcrumb_SessionTaskError_HTTP400_HasLevelError() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 400))
        task.setError(NSError(domain: "Some Error", code: 1, userInfo: nil))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .error)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(400, data["status_code"] as? Int)
        XCTAssertEqual("bad request", data["reason"] as? String)
    }
    
    func test_Breadcrumb_HTTP500_HasLevelError() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .error)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(500, data["status_code"] as? Int)
        XCTAssertEqual("internal server error", data["reason"] as? String)
    }
    
    func test_Breadcrumb_HTTP599_HasLevelError() throws {
        // Arrange
        fixture.options.enableAutoPerformanceTracing = false

        let task = createDataTask()
        task.setResponse(try createResponse(code: 599))
        let _ = try XCTUnwrap(spanForTask(task: task))
        
        //Act
        try setTaskState(task, state: .completed)
        
        //Assert
        let breadcrumbsDynamic = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        let breadcrumbs = try XCTUnwrap(breadcrumbsDynamic)
        XCTAssertEqual(breadcrumbs.count, 1)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)

        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.level, .error)
        XCTAssertEqual(breadcrumb.type, "http")
        
        let data = try XCTUnwrap(breadcrumb.data)
        XCTAssertEqual(SentryNetworkTrackerTests.testUrl, data["url"] as? String)
        XCTAssertEqual("GET", data["method"] as? String)
        XCTAssertEqual(599, data["status_code"] as? Int)
        XCTAssertEqual("server error", data["reason"] as? String)
    }

    func testResumeAfterCompleted_OnlyOneSpanCreated() throws {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        try setTaskState(task, state: .completed)
        sut.urlSessionTaskResume(task)

        assertOneSpanCreated(transaction)
    }

    func testResumeAfterCancelled_OnlyOneSpanCreated() throws {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)
        try setTaskState(task, state: .canceling)
        sut.urlSessionTaskResume(task)

        assertOneSpanCreated(transaction)
    }

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

    func testChangeStateMultipleTimesConcurrent_OneSpanFinished() throws {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        sut.urlSessionTaskResume(task)

        let queue = DispatchQueue(label: "SentryNetworkTrackerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()

        for _ in 0...100_000 {
            group.enter()
            queue.async {
                do {
                    try self.setTaskState(task, state: .completed)
                } catch {
                    XCTFail("Failed to set task state: \(error)")
                }
                group.leave()
            }
        }

        queue.activate()
        group.waitWithTimeout(timeout: 100)

        let spans = Dynamic(transaction).children as [Span]?
        XCTAssertEqual(1, spans?.count)
        let span = try XCTUnwrap(spans?.first)

        XCTAssertTrue(span.isFinished)
        //Test if it has observers. Nil means no observers
        XCTAssertNil(task.observationInfo)
    }

    func testBaggageHeader() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)
        sut.urlSessionTaskResume(task)

        let expectedBaggageHeader = transaction.traceContext?.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", expectedBaggageHeader)
    }

    func testDontOverrideBaggageHeader() {
        let sut = fixture.getSut()
        let task = createDataTask {
            var request = $0
            request.setValue("sentry-trace_id=something", forHTTPHeaderField: "baggage")
            return request
        }
        sut.urlSessionTaskResume(task)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", "sentry-trace_id=something")
    }

    func testTraceHeader() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)
        sut.urlSessionTaskResume(task)

        let children = try XCTUnwrap(Dynamic(transaction).children.asArray as? [SentrySpan])
        let networkSpan = try XCTUnwrap(children.first)
        let expectedTraceHeader = networkSpan.toTraceHeader().value()
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    func testDontOverrideTraceHeader() {
        let sut = fixture.getSut()
        let task = createDataTask {
            var request = $0
            request.setValue("test", forHTTPHeaderField: "sentry-trace")
            return request
        }
        sut.urlSessionTaskResume(task)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", "test")
    }

    @available(*, deprecated)
    func testDefaultHeadersWhenDisabled() throws {
        let sut = fixture.getSut()
        sut.disable()

        let task = createDataTask()
        _ = try XCTUnwrap(startTransaction() as? SentryTracer)
        sut.urlSessionTaskResume(task)

        let expectedTraceHeader = SentrySDKInternal.currentHub().scope.propagationContext.traceHeader.value()
        let traceContext = TraceContext(trace: SentrySDKInternal.currentHub().scope.propagationContext.traceId, options: self.fixture.options, userSegment: self.fixture.scope.userObject?.segment, replayId: nil)
        let expectedBaggageHeader = traceContext.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", expectedBaggageHeader)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    @available(*, deprecated)
    func testDefaultHeadersWhenNoTransaction() {
        let sut = fixture.getSut()
        let task = createDataTask()
        sut.urlSessionTaskResume(task)

        let expectedTraceHeader = SentrySDKInternal.currentHub().scope.propagationContext.traceHeader.value()
        let traceContext = TraceContext(trace: SentrySDKInternal.currentHub().scope.propagationContext.traceId, options: self.fixture.options, userSegment: self.fixture.scope.userObject?.segment, replayId: nil)
        let expectedBaggageHeader = traceContext.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", expectedBaggageHeader)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    func testNoHeadersForWrongUrl() throws {
        fixture.options.tracePropagationTargets = ["www.example.com"]

        let sut = fixture.getSut()
        let task = createDataTask()
        _ = try XCTUnwrap(startTransaction() as? SentryTracer)
        sut.urlSessionTaskResume(task)

        XCTAssertNil(task.currentRequest?.allHTTPHeaderFields?["baggage"])
        XCTAssertNil(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"])
    }

    func testIsTargetMatch() throws {
        // Default: all urls
        let defaultRegex = try XCTUnwrap(NSRegularExpression(pattern: ".*"))
        let sut = fixture.getSut()
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: [ defaultRegex ]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/api/projects")), withTargets: [ defaultRegex ]))

        // Strings: hostname
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: ["localhost"]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost-but-not-really")), withTargets: ["localhost"])) // works because of `contains`
        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/api/projects")), withTargets: ["localhost"]))

        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: ["www.example.com"]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/api/projects")), withTargets: ["www.example.com"]))
        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://api.example.com/api/projects")), withTargets: ["www.example.com"]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com.evil.com/api/projects")), withTargets: ["www.example.com"])) // works because of `contains`

        // Test regex
        let regex = try XCTUnwrap(NSRegularExpression(pattern: "http://www.example.com/api/.*"))
        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: [regex]))
        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/url")), withTargets: [regex]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/api/projects")), withTargets: [regex]))

        // Regex and string
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: ["localhost", regex]))
        XCTAssertFalse(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/url")), withTargets: ["localhost", regex]))
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://www.example.com/api/projects")), withTargets: ["localhost", regex]))

        // String and integer (which isn't valid, make sure it doesn't crash)
        XCTAssertTrue(sut.isTargetMatch(try XCTUnwrap(URL(string: "http://localhost")), withTargets: ["localhost", 123]))
    }

    func testCaptureHTTPClientErrorRequest() throws {
        let sut = fixture.getSut()

        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?query=myQuery#myFragment"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = ["test": "test", "Cookie": "myCookie", "Set-Cookie": "myCookie"]
        request.allHTTPHeaderFields = headers

        let task = URLSessionDataTaskMock(request: request)
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        guard let envelope = self.fixture.hub.capturedEventsWithScopes.first else {
            XCTFail("Expected to capture 1 event")
            return
        }
        let sentryRequest = try XCTUnwrap(envelope.event.request)

        XCTAssertEqual(sentryRequest.url, "https://www.domain.com/api")
        XCTAssertEqual(sentryRequest.method, "GET")
        XCTAssertEqual(sentryRequest.bodySize, 652)
        XCTAssertNil(sentryRequest.cookies)
        XCTAssertEqual(sentryRequest.headers, ["test": "test"])
        XCTAssertEqual(sentryRequest.fragment, "myFragment")
        XCTAssertEqual(sentryRequest.queryString, "query=myQuery")
    }
    
    func testCaptureHTTPClientErrorRequest_graphQLEnabled() throws {
        let sut = fixture.getSut()
        
        let task = createDataTask {
            var request = $0
            
            request.httpMethod = "POST"
            request.httpBody = Data("""
            {
                "operationName": "someOperationName",
                "variables": { "a": 1 },
                "query": "query someOperationName { someField }"
            }
            """.utf8)
            request.allHTTPHeaderFields = ["content-type": "application/json"]
            
            return request
        }
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)
        
        let envelope = try XCTUnwrap(
            fixture.hub.capturedEventsWithScopes.first,
            "Expected to capture 1 event"
        )
        
        let graphQLContext = try XCTUnwrap(
            envelope.event.context?["graphql"],
            "Expected 'graphql' object in context"
        )
        
        XCTAssertEqual(graphQLContext.count, 1)
        let operationName = try XCTUnwrap(
            graphQLContext["operation_name"] as? String,
            "Expected graphql.operation_name to be a String"
        )
        
        XCTAssertEqual(operationName, "someOperationName")
    }

    func testCaptureHTTPClientErrorRequest_noSecurityInfo() throws {
        let sut = fixture.getSut()

        let url = try XCTUnwrap(URL(string: "https://user:password@www.domain.com/api?query=myQuery#myFragment"))
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = fixture.securityHeader

        let task = URLSessionDataTaskMock(request: request)
        task.setResponse(try createResponse(code: 500))
        sut.urlSessionTask(task, setState: .completed)

        guard let envelope = self.fixture.hub.capturedEventsWithScopes.first else {
            XCTFail("Expected to capture 1 event")
            return
        }
        let sentryRequest = try XCTUnwrap(envelope.event.request)

        XCTAssertEqual(sentryRequest.url, "https://[Filtered]:[Filtered]@www.domain.com/api")
        XCTAssertEqual(sentryRequest.headers, ["VALID_HEADER": "value"])
    }

    func testCaptureHTTPClientErrorResponse() throws {
        let sut = fixture.getSut()
        let task = createDataTask()

        let headers = ["test": "test", "Cookie": "myCookie", "Set-Cookie": "myCookie"]
        let response = try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: headers))
        task.setResponse(response)

        sut.urlSessionTask(task, setState: .completed)

        guard let envelope = self.fixture.hub.capturedEventsWithScopes.first else {
            XCTFail("Expected to capture 1 event")
            return
        }
        let sentryResponse = try XCTUnwrap(envelope.event.context?["response"])

        XCTAssertEqual(sentryResponse["status_code"] as? NSNumber, 500)
        XCTAssertEqual(sentryResponse["headers"] as? [String: String], ["test": "test"])
        XCTAssertNil(sentryResponse["cookies"])
        XCTAssertEqual(sentryResponse["body_size"] as? NSNumber, 256)
    }

    func testCaptureHTTPClientErrorResponse_noSecurityHeader() throws {
        let sut = fixture.getSut()
        let task = createDataTask()

        let headers = fixture.securityHeader
        let response = try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: headers))
        task.setResponse(response)
        sut.urlSessionTask(task, setState: .completed)

        guard let envelope = self.fixture.hub.capturedEventsWithScopes.first else {
            XCTFail("Expected to capture 1 event")
            return
        }
        let sentryResponse = try XCTUnwrap(envelope.event.context?["response"])

        XCTAssertEqual(sentryResponse["headers"] as? [String: String], ["VALID_HEADER": "value"])
    }

    func testCaptureHTTPClientErrorException() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        let envelope = try XCTUnwrap(self.fixture.hub.capturedEventsWithScopes.first)
        
        let exceptions = try XCTUnwrap(envelope.event.exceptions)
        XCTAssertEqual(exceptions.count, 1)
        let exception = try XCTUnwrap(exceptions.first)

        XCTAssertEqual(exception.type, "HTTPClientError")
        XCTAssertEqual(exception.value, "HTTP Client Error with status code: 500")

        let stackTrace = try XCTUnwrap(exception.stacktrace)
        XCTAssertTrue(try XCTUnwrap(stackTrace.snapshot).boolValue)
        XCTAssertNotNil(stackTrace.frames)
    }

    func testDoesNotCaptureHTTPClientErrorIfDisabled() throws {
        let sut = fixture.getSut()
        sut.disable()
        sut.enableNetworkTracking()
        sut.enableNetworkBreadcrumbs()

        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertNil(fixture.hub.capturedEventsWithScopes.first)
    }

    func testDoesNotCaptureHTTPClientErrorIfNotStatusCodeRange() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        task.setResponse(try createResponse(code: 200))

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertNil(fixture.hub.capturedEventsWithScopes.first)
    }

    func testDoesNotCaptureHTTPClientErrorIfNotTarget() throws {
        fixture.options.failedRequestTargets = ["www.example.com"]

        let sut = fixture.getSut()
        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertNil(fixture.hub.capturedEventsWithScopes.first)
    }

    private func setTaskState(_ task: URLSessionTaskMock, state: URLSessionTask.State) throws {
        fixture.getSut().urlSessionTask(try XCTUnwrap(task as? URLSessionTask), setState: state)
        task.state = state
    }

    private func assertStatus(status: SentrySpanStatus, state: URLSessionTask.State, response: URLResponse, configSut: ((SentryNetworkTracker) -> Void)? = nil) throws {
        let sut = fixture.getSut()
        configSut?(sut)

        let task = createDataTask()

        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)

        let spans = Dynamic(transaction).children as [Span]?
        let span = try XCTUnwrap(spans?.first)

        task.setResponse(response)

        sut.urlSessionTask(task, setState: state)

        let httpStatusCode = span.data["http.response.status_code"] as? String

        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual("\(httpResponse.statusCode)", httpStatusCode)
        } else {
            XCTAssertNil(httpStatusCode)
        }

        let path = span.data["url"] as? String
        let method = span.data["http.request.method"] as? String
        let requestType = span.data["type"] as? String
        let query = span.data["http.query"] as? String
        let fragment = span.data["http.fragment"] as? String
        let graphql = span.data["graphql_operation_name"] as? String

        XCTAssertEqual(path, "https://www.domain.com/api")
        XCTAssertEqual(method, try XCTUnwrap(task.currentRequest?.httpMethod))
        XCTAssertEqual(requestType, "fetch")
        XCTAssertEqual(query, "query=value&query2=value2")
        XCTAssertEqual(fragment, "fragment")
        XCTAssertNil(graphql)

        XCTAssertEqual(span.status, status)
        XCTAssertNil(task.observationInfo)
    }

    private func assertCompletedSpan(_ task: URLSessionDataTaskMock, _ span: Span) throws {
        XCTAssertNotNil(span)
        XCTAssertFalse(span.isFinished)
        XCTAssertEqual(task.currentRequest?.value(forHTTPHeaderField: SENTRY_TRACE_HEADER), span.toTraceHeader().value())
        try setTaskState(task, state: .completed)
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

    private func createResponse(code: Int) throws -> URLResponse {
        return try XCTUnwrap(HTTPURLResponse(url: SentryNetworkTrackerTests.fullUrl, statusCode: code, httpVersion: "1.1", headerFields: nil))
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }

    private func assertSpanDuration(span: Span, expectedDuration: TimeInterval) throws {
        let duration = try XCTUnwrap(span.timestamp).timeIntervalSince(span.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }

    private func createDataTask(method: String = "GET", modifyRequest: ((URLRequest) -> (URLRequest))? = nil) -> URLSessionDataTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        request.httpMethod = method
        request.httpBody = fixture.nsUrlRequest.httpBody
        fixture.nsUrlRequest.allHTTPHeaderFields?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let modifyRequest = modifyRequest {
            request = modifyRequest(request)
        }
        return URLSessionDataTaskMock(request: request)
    }

    private func createDownloadTask(method: String = "GET") -> URLSessionDownloadTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        request.httpMethod = method
        return URLSessionDownloadTaskMock(request: request)
    }

    private func createUploadTask(method: String = "GET") -> URLSessionUploadTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        request.httpMethod = method
        return URLSessionUploadTaskMock(request: request)
    }

    private func createStreamTask(method: String = "GET") -> URLSessionStreamTaskMock {
        var request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        request.httpMethod = method
        return URLSessionStreamTaskMock(request: request)
    }
}
