@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import ObjectiveC
import XCTest

// swiftlint:disable file_length
private typealias TestNetworkTracker = SentryDefaultNetworkTracker<SentryDependencyContainer>

class SentryNetworkTrackerTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
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
            options.enablePropagateTraceparent = true
            sentryTask = URLSessionDataTaskMock(request: URLRequest(url: URL(string: options.dsn!)!))
            scope = Scope()
            client = TestClient(options: options)
            hub = TestHub(client: client, andScope: scope)
        }

        func getSut() -> TestNetworkTracker {
            let result = TestNetworkTracker(
                options: options,
                dependencies: SentryDependencyContainer.sharedInstance()
            )
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
        SentrySDK.setStart(with: fixture.options)
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

        XCTAssertNil(task.trackerSpan)
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

    func testSetState_whenSDKOptionsAreNil_shouldNotCaptureBreadcrumb() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let task = createDataTask()
        task.setResponse(try createResponse(code: 200))
        SentrySDKInternal.setStart(with: nil)

        // -- Act --
        sut.urlSessionTask(task, setState: .completed)

        // -- Assert --
        let breadcrumbs = Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertTrue(breadcrumbs?.isEmpty ?? true)
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

    func testSuspendedRequest_whenSuspended_shouldNotFinishSpan() throws {
        // Suspended is a non-terminal state — the task can be resumed later.
        // The span should remain open.

        // -- Arrange --
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Act --
        try setTaskState(task, state: .suspended)

        // -- Assert --
        XCTAssertFalse(span.isFinished)
    }

    func testSuspendedRequest_whenResumedAndCompleted_shouldFinishSpan() throws {
        // A suspended task that is later resumed and completed should
        // finish the span with the correct status.

        // -- Arrange --
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))
        task.setResponse(try createResponse(code: 200))

        // -- Act --
        try setTaskState(task, state: .suspended)
        try setTaskState(task, state: .running)
        try setTaskState(task, state: .completed)

        // -- Assert --
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .ok)
    }

    func testSuspendedRequest_whenCancelledWhileSuspended_shouldRecordBreadcrumbAndFinishSpan() throws {
        // A task cancelled while suspended should still record a breadcrumb
        // and finish the span with cancelled status, consistent with the
        // running → canceling path.

        // -- Arrange --
        let task = createDataTask()
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Act --
        try setTaskState(task, state: .suspended)
        try setTaskState(task, state: .canceling)

        // -- Assert --
        XCTAssertTrue(span.isFinished)
        XCTAssertEqual(span.status, .cancelled)

        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        XCTAssertEqual(breadcrumbs.count, 1)

        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        XCTAssertEqual(breadcrumb.category, "http")
        XCTAssertEqual(breadcrumb.type, "http")
        #if SDK_V10
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
        XCTAssertEqual(try XCTUnwrap(breadcrumb.data?["method"] as? String), "GET")
    }

    func testSuspendedRequest_whenResumedAfterSuspend_shouldPreserveOriginalStartDate() throws {
        // When a task is suspended and resumed, the breadcrumb request_start
        // should reflect the original start time, not the time of the last resume.

        // -- Arrange --
        let sut = fixture.getSut()
        let task = createDataTask()
        _ = startTransaction()

        let timeBeforeFirstResume = fixture.dateProvider.date()
        sut.urlSessionTaskResume(task)
        let timeAfterFirstResume = fixture.dateProvider.date()

        try setTaskState(task, state: .suspended)
        advanceTime(bySeconds: 1)
        let timeBeforeSecondResume = fixture.dateProvider.date()
        sut.urlSessionTaskResume(task)

        // -- Act --
        task.setResponse(try createResponse(code: 200))
        try setTaskState(task, state: .completed)

        // -- Assert --
        let breadcrumbs = try XCTUnwrap(Dynamic(fixture.scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        let requestStart = try XCTUnwrap(breadcrumb.data?["request_start"] as? Date)

        // The start date should be from the first resume window, not the second
        XCTAssertGreaterThanOrEqual(requestStart, timeBeforeFirstResume,
            "request_start should be no earlier than the first resume")
        XCTAssertLessThanOrEqual(requestStart, timeAfterFirstResume,
            "request_start should be no later than right after the first resume")
        XCTAssertLessThan(requestStart, timeBeforeSecondResume,
            "request_start should be before the second resume, proving the original date was preserved")
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

        XCTAssertEqual(span.spanDescription, "GET https://www.domain.com/api")
        XCTAssertEqual(SentryNetworkTrackerTests.origin, span.origin)
    }

    func testSpanDescriptionNameWithPost() throws {
        let task = createDataTask(method: "POST")
        let span = try XCTUnwrap(spanForTask(task: task))

        XCTAssertEqual(span.spanDescription, "POST https://www.domain.com/api")
        XCTAssertEqual(SentryNetworkTrackerTests.origin, span.origin)
    }

#if SDK_V10
    func testSpan_whenURLHasQuery_shouldStoreFilteredQueryInURLData() throws {
        // -- Arrange --
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?token=secret&page=2"))
        let task = URLSessionDataTaskMock(request: URLRequest(url: url))

        // -- Act --
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Assert --
        XCTAssertEqual(span.data["url"] as? String, "https://www.domain.com/api?token=[Filtered]&page=2")
        XCTAssertEqual(span.spanDescription, "GET https://www.domain.com/api")
    }

    func testSpan_whenURLQueryParamsAreOff_shouldNotStoreQueryInURLData() throws {
        // -- Arrange --
        fixture.options.sendDefaultPii = true
        fixture.options.dataCollection.urlQueryParams = .off
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?token=secret&page=2"))
        let task = URLSessionDataTaskMock(request: URLRequest(url: url))

        // -- Act --
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Assert --
        XCTAssertEqual(span.data["url"] as? String, "https://www.domain.com/api")
        XCTAssertNil(span.data["http.query"])
        XCTAssertEqual(span.spanDescription, "GET https://www.domain.com/api")
    }

    func testSpan_whenSendDefaultPiiIsFalse_shouldUseConfiguredQueryParamBehavior() throws {
        // -- Arrange --
        fixture.options.sendDefaultPii = false
        fixture.options.dataCollection.urlQueryParams = .off
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?forwarded=192.0.2.1&page=2"))
        let task = URLSessionDataTaskMock(request: URLRequest(url: url))

        // -- Act --
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Assert --
        XCTAssertEqual(span.data["url"] as? String, "https://www.domain.com/api")
        XCTAssertNil(span.data["http.query"])
    }

    func testSpan_whenSendDefaultPiiIsTrue_shouldUseConfiguredQueryParamBehavior() throws {
        // -- Arrange --
        fixture.options.sendDefaultPii = true
        fixture.options.dataCollection = SentryDataCollection.Options()
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?forwarded=192.0.2.1&page=2"))
        let task = URLSessionDataTaskMock(request: URLRequest(url: url))

        // -- Act --
        let span = try XCTUnwrap(spanForTask(task: task))

        // -- Assert --
        XCTAssertEqual(span.data["http.query"] as? String, "forwarded=192.0.2.1&page=2")
        XCTAssertEqual(span.spanDescription, "GET https://www.domain.com/api")
    }
#endif // SDK_V10

    func testSpanData_VolatileCurrentRequest_UsesSnapshot() throws {
        var request = URLRequest(url: SentryNetworkTrackerTests.fullUrl)
        request.httpMethod = "GET"
        let task = VolatileRequestTaskMock(request: request)
        task.currentRequestAccessLimit = 1

        let sut = fixture.getSut()
        let transaction = startTransaction()
        sut.urlSessionTaskResume(task)

        let spans = Dynamic(transaction).children as [Span]?
        let span = try XCTUnwrap(spans?.first)

        XCTAssertEqual(span.spanDescription, "GET https://www.domain.com/api")
        XCTAssertEqual(span.data["http.request.method"] as? String, "GET")
    }

    func testStatusForTaskRunning() {
        let sut = fixture.getSut()
        let task = createDataTask()
        let status = sut.status(for: task, state: .running)
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
        #if SDK_V10
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(payload["description"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
        XCTAssertEqual(payload["op"] as? String, "resource.http")
        XCTAssertEqual(payload["startTimestamp"] as? Double, start.timeIntervalSince1970)
        XCTAssertEqual(payload["endTimestamp"] as? Double, crumb.timestamp?.timeIntervalSince1970)
        XCTAssertEqual(payloadData["statusCode"] as? Int, 200)
        XCTAssertEqual(payloadData["query"] as? String, "query=value&query2=value2")
        XCTAssertEqual(payloadData["fragment"] as? String, "fragment")
    }

#if os(iOS) || os(tvOS)
    /// Simple case - when network details are enabled, `addBreadcrumbForSessionTask` will include
    /// serialized network details in the breadcrumb data.
    func testAddBreadcrumb_withNetworkDetails_shouldIncludeSerializedDetailsInBreadcrumbData() throws {
        guard #available(iOS 16.0, tvOS 16.0, *) else { return }

        // -- Arrange --
        let testUrl = URL(string: "https://api.example.com/users")!
        let options = Options()
        options.dsn = "https://key@sentry.io/1234"
        options.sessionReplay.networkDetailAllowUrls = ["api.example.com"]
        options.sessionReplay.networkResponseHeaders = ["Cache-Control"]
        options.sessionReplay.networkCaptureBodies = false

        let scope = Scope()
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        SentrySDK.setStart(with: options)

        let tracker = TestNetworkTracker(
            options: options,
            dependencies: SentryDependencyContainer.sharedInstance()
        )
        tracker.enableNetworkTracking()
        tracker.enableNetworkBreadcrumbs()

        var request = URLRequest(url: testUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSessionDataTaskMock(request: request)

        let httpResponse = try XCTUnwrap(HTTPURLResponse(
            url: testUrl, statusCode: 200, httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json", "Cache-Control": "no-cache"]
        ))
        task.setResponse(httpResponse)

        // -- Act --
        // 1. setState(.running) triggers captureRequestDetails (associates details with task).
        tracker.urlSessionTask(task, setState: .running)

        // 2. completionHandler fires, capturing response details on the associated object.
        tracker.captureResponseDetails(
            Data(), response: httpResponse, request: testUrl, task: task
        )

        // 3. setState(.completed) triggers addBreadcrumbForSessionTask, which serializes
        //    the now-complete details (request + response) into the breadcrumb.
        tracker.urlSessionTask(task, setState: .completed)

        // -- Assert --
        let breadcrumbs = try XCTUnwrap(Dynamic(scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        let detailsObject = try XCTUnwrap(
            breadcrumb.data?[SentryReplayNetworkDetails.replayNetworkDetailsKey] as? SentryReplayNetworkDetails
        )
        let networkDetails = detailsObject.serialize()

        XCTAssertEqual(networkDetails["method"] as? String, "POST")
        XCTAssertEqual(networkDetails["statusCode"] as? Int, 200)

        // Verify request details show up
        let requestDict = try XCTUnwrap(networkDetails["request"] as? [String: Any])
        let requestHeaders = try XCTUnwrap(requestDict["headers"] as? [String: String])
        // "Content-Type" is always extracted when present.
        XCTAssertEqual(requestHeaders["Content-Type"], "application/json")
        XCTAssertEqual(requestHeaders.count, 1, "Only Content-Type should be captured (no networkRequestHeaders configured)")

        // Verify response details show up
        let responseDict = try XCTUnwrap(networkDetails["response"] as? [String: Any])
        let responseHeaders = try XCTUnwrap(responseDict["headers"] as? [String: String])
        // "Content-Type" is always extracted when present.
        XCTAssertEqual(responseHeaders["Content-Type"], "application/json")
        XCTAssertEqual(responseHeaders["Cache-Control"], "no-cache")
        XCTAssertEqual(responseHeaders.count, 2, "Only Content-Type and the configured Cache-Control should be captured")

        clearTestState()
    }

    func testCaptureRequestDetails_whenAlreadyCaptured_shouldKeepOriginalRequest() throws {
        guard #available(iOS 16.0, tvOS 16.0, *) else { return }

        // -- Arrange --
        let testUrl = URL(string: "https://api.example.com/users")!
        fixture.options.sessionReplay.networkDetailAllowUrls = ["api.example.com"]
        fixture.options.sessionReplay.networkRequestHeaders = ["X-Request"]

        var originalRequest = URLRequest(url: testUrl)
        originalRequest.httpMethod = "POST"
        originalRequest.setValue("original", forHTTPHeaderField: "X-Request")
        let task = URLSessionDataTaskMock(request: originalRequest)
        let tracker = fixture.getSut()

        tracker.urlSessionTask(task, setState: .running)

        var redirectedRequest = URLRequest(url: testUrl)
        redirectedRequest.httpMethod = "GET"
        redirectedRequest.setValue("redirected", forHTTPHeaderField: "X-Request")
        task.setCurrentRequest(redirectedRequest)

        // -- Act --
        tracker.urlSessionTask(task, setState: .completed)

        // -- Assert --
        guard case .valid(let details) = task.networkDetails else {
            return XCTFail("Expected network details")
        }
        let request = try XCTUnwrap(details.serialize()["request"] as? [String: Any])
        let headers = try XCTUnwrap(request["headers"] as? [String: String])
        XCTAssertEqual(headers["X-Request"], "original")
    }

    /// Regression test for #8388: `captureResponseDetails` must read the response `Content-Type`
    /// case-insensitively. HTTP/2 and HTTP/3 lowercase field names, so the server sends
    /// `content-type`. If the tracker reverts to the case-sensitive `allHeaderFields["Content-Type"]`
    /// subscript, `contentType` becomes nil and the body degrades to a `[Body not captured …]`
    /// placeholder — failing the body assertion below.
    ///
    /// `HTTPURLResponse` canonicalizes `Content-Type` in its initializer, so we use
    /// `LowercasedHeadersHTTPURLResponse` to model the lowercased wire casing.
    func testCaptureResponseDetails_withLowercasedContentType_parsesJSONBody() throws {
        guard #available(iOS 16.0, tvOS 16.0, *) else { return }

        // -- Arrange --
        let testUrl = URL(string: "https://api.example.com/users")!
        let options = Options()
        options.dsn = "https://key@sentry.io/1234"
        options.sessionReplay.networkDetailAllowUrls = ["api.example.com"]
        options.sessionReplay.networkCaptureBodies = true

        let scope = Scope()
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: scope)
        SentrySDKInternal.setCurrentHub(hub)
        SentrySDK.setStart(with: options)

        let tracker = TestNetworkTracker(
            options: options,
            dependencies: SentryDependencyContainer.sharedInstance()
        )
        tracker.enableNetworkTracking()
        tracker.enableNetworkBreadcrumbs()

        let request = URLRequest(url: testUrl)
        let task = URLSessionDataTaskMock(request: request)

        // The server sends the header lowercased, as HTTP/2 and HTTP/3 require.
        let httpResponse = try XCTUnwrap(LowercasedHeadersHTTPURLResponse(
            url: testUrl, statusCode: 200, headers: ["content-type": "application/json"]
        ))
        task.setResponse(httpResponse)

        let jsonBody = Data(#"{"key":"value"}"#.utf8)

        // -- Act --
        tracker.urlSessionTask(task, setState: .running)
        tracker.captureResponseDetails(jsonBody, response: httpResponse, request: testUrl, task: task)
        tracker.urlSessionTask(task, setState: .completed)

        // -- Assert --
        let breadcrumbs = try XCTUnwrap(Dynamic(scope).breadcrumbArray as [Breadcrumb]?)
        let breadcrumb = try XCTUnwrap(breadcrumbs.first)
        let detailsObject = try XCTUnwrap(
            breadcrumb.data?[SentryReplayNetworkDetails.replayNetworkDetailsKey] as? SentryReplayNetworkDetails
        )
        let networkDetails = detailsObject.serialize()
        let responseDict = try XCTUnwrap(networkDetails["response"] as? [String: Any])

        // The Content-Type is read and reported with the lowercased wire casing the server sent.
        let responseHeaders = try XCTUnwrap(responseDict["headers"] as? [String: String])
        XCTAssertEqual(responseHeaders["content-type"], "application/json")

        // The Content-Type is used to parse the body as JSON. Reverting the case-insensitive lookup
        // makes `contentType` nil, so the body becomes the "[Body not captured]" placeholder and the
        // unwrap below fails.
        let bodyDict = try XCTUnwrap(responseDict["body"] as? [String: Any])
        let parsedBody = try XCTUnwrap(bodyDict["body"] as? [String: Any])
        XCTAssertEqual(parsedBody["key"] as? String, "value")

        clearTestState()
    }

    /// `HTTPURLResponse` whose `allHeaderFields` returns the exact (lowercased) casing a server
    /// sends over HTTP/2 or HTTP/3. The public initializer canonicalizes well-known headers such as
    /// `Content-Type`, so overriding `allHeaderFields` is the only way to model the wire casing and
    /// reproduce #8388.
    private final class LowercasedHeadersHTTPURLResponse: HTTPURLResponse, @unchecked Sendable {
        private let wireHeaders: [AnyHashable: Any]

        init?(url: URL, statusCode: Int, headers: [String: String]) {
            self.wireHeaders = headers
            super.init(url: url, statusCode: statusCode, httpVersion: "2.0", headerFields: headers)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // Intentionally returns the raw (lowercased) wire casing to reproduce #8388; that's the
        // whole point of this mock, so the case-sensitivity lint rule doesn't apply here.
        // swiftlint:disable:next avoid_all_header_fields
        override var allHeaderFields: [AnyHashable: Any] {
            wireHeaders
        }
    }

#endif

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
        #if SDK_V10
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(breadcrumb.data?["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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
        #if SDK_V10
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(data["url"] as? String, "https://www.domain.com/api")
#endif // SDK_V10
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

        let loopCount = 1_000

        let expectation = XCTestExpectation(description: "Resume called multiple times concurrently")
        expectation.expectedFulfillmentCount = loopCount
        expectation.assertForOverFulfill = true

        for _ in 0..<loopCount {

            queue.async {
                sut.urlSessionTaskResume(task)
                task.state = .completed

                expectation.fulfill()
            }
        }

        queue.activate()
        wait(for: [expectation], timeout: 10)

        assertOneSpanCreated(transaction)
    }

    func testChangeStateMultipleTimesConcurrent_OneSpanFinished() throws {
        let task = createDataTask()
        let sut = fixture.getSut()
        let transaction = startTransaction()
        sut.urlSessionTaskResume(task)

        let queue = DispatchQueue(label: "SentryNetworkTrackerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])

        let loopCount = 1_000

        let expectation = XCTestExpectation(description: "Change state multiple times concurrently")
        expectation.expectedFulfillmentCount = loopCount
        expectation.assertForOverFulfill = true

        for _ in 0..<loopCount {

            queue.async {
                do {
                    try self.setTaskState(task, state: .completed)
                } catch {
                    XCTFail("Failed to set task state: \(error)")
                }

                expectation.fulfill()
            }
        }

        queue.activate()

        wait(for: [expectation], timeout: 10)

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

        let children = try XCTUnwrap(Dynamic(transaction).children.asArray as? [SentrySpanInternal])
        let networkSpan = try XCTUnwrap(children.first)
        let expectedTraceHeader = networkSpan.toTraceHeader().value()
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    func testTraceHeader_whenNetworkTrackingDisabledAndTransactionBoundToScope_shouldUseTransactionTraceId() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        sut.disable()
        sut.enableNetworkBreadcrumbs()
        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)

        // -- Act --
        sut.urlSessionTaskResume(task)

        // -- Assert --
        let traceHeader = try XCTUnwrap(task.currentRequest?.value(forHTTPHeaderField: "sentry-trace"))
        let propagatedTraceId = traceHeader.components(separatedBy: "-").first
        XCTAssertEqual(propagatedTraceId, transaction.traceId.sentryIdString)
    }

    func testTraceHeader_whenScopeSpanHasNoTracer_shouldUseNetworkSpanTraceHeader() {
        // -- Arrange --
        let sut = fixture.getSut()
        let task = createDataTask()
        let span = NetworkTrackerTestSpan()
        fixture.scope.span = span

        // -- Act --
        sut.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(
            task.currentRequest?.value(forHTTPHeaderField: "sentry-trace"),
            span.toTraceHeader().value()
        )
    }

    func testTraceHeader_whenNetworkTrackingDisabledAndTracerHasNoBaggage_shouldUseSpanTraceHeader() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        sut.disable()
        sut.enableNetworkBreadcrumbs()
        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)
        fixture.options.dsn = nil

        // -- Act --
        sut.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(
            task.currentRequest?.value(forHTTPHeaderField: "sentry-trace"),
            transaction.toTraceHeader().value()
        )
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

    func testPropagateTraceparent() throws {
        // Arrange
        let sut = fixture.getSut()
        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)

        // Act
        sut.urlSessionTaskResume(task)

        // Assert
        let children = try XCTUnwrap(Dynamic(transaction).children.asArray as? [SentrySpanInternal])
        let networkSpan = try XCTUnwrap(children.first)

        let traceHeader = transaction.toTraceHeader()
        let expectedTraceHeader = "00-\(traceHeader.traceId.sentryIdString)-\(networkSpan.spanId.sentrySpanIdString)-00"
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["traceparent"] ?? "", expectedTraceHeader)
    }

    func testPropagateTraceparent_WhenDisabled_NotAdded() throws {
        // Arrange
        let sut = fixture.getSut()
        let task = createDataTask()
        _ = try XCTUnwrap(startTransaction() as? SentryTracer)
        fixture.options.enablePropagateTraceparent = false

        // Act
        sut.urlSessionTaskResume(task)

        // Assert
        XCTAssertNil(task.currentRequest?.allHTTPHeaderFields?["traceparent"])
    }

    func testDontOverrideTraceparent() {
        let sut = fixture.getSut()
        let task = createDataTask {
            var request = $0
            request.setValue("test", forHTTPHeaderField: "traceparent")
            return request
        }
        sut.urlSessionTaskResume(task)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["traceparent"] ?? "", "test")
    }

    func testDefaultHeadersWhenDisabled() throws {
        let sut = fixture.getSut()
        sut.disable()

        let task = createDataTask()
        let transaction = try XCTUnwrap(startTransaction() as? SentryTracer)
        sut.urlSessionTaskResume(task)

        let expectedTraceHeader = transaction.toTraceHeader().value()
        let expectedBaggageHeader = transaction.traceContext?.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", expectedBaggageHeader)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    func testDefaultHeadersWhenNoTransaction() {
        let sut = fixture.getSut()
        let task = createDataTask()
        sut.urlSessionTaskResume(task)

        let expectedTraceHeader = SentrySDKInternal.currentHub().scope.propagationContext.traceHeader.value()
        let traceContext = TraceContext(trace: SentrySDKInternal.currentHub().scope.propagationContext.traceId, options: self.fixture.options, replayId: nil)
        let expectedBaggageHeader = traceContext.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["baggage"] ?? "", expectedBaggageHeader)
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["sentry-trace"] ?? "", expectedTraceHeader)
    }

    func testDefaultTraceHeader_whenNoTransactionAndDsnIsNil_shouldUsePropagationContext() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let task = createDataTask()
        fixture.options.dsn = nil

        // -- Act --
        sut.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(
            task.currentRequest?.value(forHTTPHeaderField: "sentry-trace"),
            fixture.scope.propagationContext.traceHeader.value()
        )
        let baggage = try XCTUnwrap(task.currentRequest?.value(forHTTPHeaderField: "baggage"))
        XCTAssertTrue(baggage.contains("sentry-trace_id="))
        XCTAssertFalse(baggage.contains("sentry-public_key="))
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

    func testCaptureHTTPClientErrorRequest() throws {
        let sut = fixture.getSut()

        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?query=myQuery#myFragment"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let headers = ["test": "test", "Cookie": "theme=dark", "Set-Cookie": "locale=en; HttpOnly"]
        request.allHTTPHeaderFields = headers

        let task = URLSessionDataTaskMock(request: request)
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")
        let capturedErrorEvent = try XCTUnwrap(self.fixture.hub.capturedErrorEvents.first)
        let sentryRequest = try XCTUnwrap(capturedErrorEvent.request)

#if SDK_V10
        XCTAssertEqual(sentryRequest.url, "https://www.domain.com/api?query=myQuery")
#else
        XCTAssertEqual(sentryRequest.url, "https://www.domain.com/api")
#endif // SDK_V10
        XCTAssertEqual(sentryRequest.method, "GET")
        XCTAssertEqual(sentryRequest.bodySize, 652)
#if SDK_V10
        XCTAssertEqual(sentryRequest.cookies, ["theme": "dark", "locale": "en"])
#else
        XCTAssertNil(sentryRequest.cookies)
#endif // SDK_V10
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

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")
        let capturedErrorEvent = try XCTUnwrap(fixture.hub.capturedErrorEvents.first)

        let graphQLContext = try XCTUnwrap(
            capturedErrorEvent.context?["graphql"],
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

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")
        let capturedErrorEvent = try XCTUnwrap(self.fixture.hub.capturedErrorEvents.first)

        let sentryRequest = try XCTUnwrap(capturedErrorEvent.request)

#if SDK_V10
        XCTAssertEqual(
            sentryRequest.url,
            "https://[Filtered]:[Filtered]@www.domain.com/api?query=myQuery"
        )
#else
        XCTAssertEqual(sentryRequest.url, "https://[Filtered]:[Filtered]@www.domain.com/api")
#endif // SDK_V10
#if SDK_V10
        XCTAssertEqual(sentryRequest.headers, [
            "Authorization": "[Filtered]",
            "Cookie": "[Filtered]",
            "Set-Cookie": "[Filtered]",
            "Proxy-Authorization": "[Filtered]",
            "X-FORWARDED-FOR": "value",
            "X-API-KEY": "[Filtered]",
            "X-REAL-IP": "value",
            "REMOTE-ADDR": "value",
            "FORWARDED": "value",
            "X-CSRF-TOKEN": "[Filtered]",
            "X-CSRFTOKEN": "[Filtered]",
            "X-XSRF-TOKEN": "[Filtered]",
            "VALID_HEADER": "value"
        ])
#else
        XCTAssertEqual(sentryRequest.headers, ["VALID_HEADER": "value"])
#endif // SDK_V10
    }

    func testCaptureHTTPClientErrorRequest_whenHeaderNamePartiallyMatchesSensitiveTerm_shouldFilterValue() throws {
#if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
#else
        // -- Arrange --
        let task = createDataTask { request in
            var request = request
            request.allHTTPHeaderFields = ["X-Auth-Token": "secret-token"]
            return request
        }
        task.setResponse(try createResponse(code: 500))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let request = try XCTUnwrap(fixture.hub.capturedErrorEvents.first?.request)
        XCTAssertEqual(request.headers, ["X-Auth-Token": "[Filtered]"])
#endif // SDK_V10
    }

    func testCaptureHTTPClientErrorResponse() throws {
        let sut = fixture.getSut()
        let task = createDataTask()

        let headers = ["test": "test", "Cookie": "theme=dark", "Set-Cookie": "locale=en; HttpOnly"]
        let response = try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: headers))
        task.setResponse(response)

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")

        let capturedErrorEvent = try XCTUnwrap(self.fixture.hub.capturedErrorEvents.first)

        let sentryResponse = try XCTUnwrap(capturedErrorEvent.context?["response"])

        XCTAssertEqual(sentryResponse["status_code"] as? NSNumber, 500)
        XCTAssertEqual(sentryResponse["headers"] as? [String: String], ["test": "test"])
#if SDK_V10
        XCTAssertEqual(sentryResponse["cookies"] as? [String: String], ["theme": "dark", "locale": "en"])
#else
        XCTAssertNil(sentryResponse["cookies"])
#endif // SDK_V10
        XCTAssertEqual(sentryResponse["body_size"] as? NSNumber, 256)
    }

    func testCaptureHTTPClientErrorResponse_whenHeadersAreEmpty_shouldIncludeEmptyHeaders() throws {
        // -- Arrange --
        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let response = try XCTUnwrap(fixture.hub.capturedErrorEvents.first?.context?["response"])
        XCTAssertEqual(response["headers"] as? [String: String], [:])
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

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")
        let capturedErrorEvent = try XCTUnwrap(self.fixture.hub.capturedErrorEvents.first)

        let sentryResponse = try XCTUnwrap(capturedErrorEvent.context?["response"])

#if SDK_V10
        XCTAssertEqual(sentryResponse["headers"] as? [String: String], [
            "Authorization": "[Filtered]",
            "Cookie": "[Filtered]",
            "Set-Cookie": "[Filtered]",
            "Proxy-Authorization": "[Filtered]",
            "X-FORWARDED-FOR": "value",
            "X-API-KEY": "[Filtered]",
            "X-REAL-IP": "value",
            "REMOTE-ADDR": "value",
            "FORWARDED": "value",
            "X-CSRF-TOKEN": "[Filtered]",
            "X-CSRFTOKEN": "[Filtered]",
            "X-XSRF-TOKEN": "[Filtered]",
            "VALID_HEADER": "value"
        ])
#else
        XCTAssertEqual(sentryResponse["headers"] as? [String: String], ["VALID_HEADER": "value"])
#endif // SDK_V10
    }

    func testCaptureHTTPClientErrorRequest_whenHeadersAreOffAndCookiesEnabled_shouldCollectOnlyCookies() throws {
        // -- Arrange --
#if SDK_V10
        fixture.options.dataCollection.httpHeaders.request = .off
        fixture.options.dataCollection.cookies = .denyList()
#endif // SDK_V10
        let task = createDataTask { request in
            var request = request
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json",
                "Cookie": "theme=dark; session=secret"
            ]
            return request
        }
        task.setResponse(try createResponse(code: 500))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let request = try XCTUnwrap(fixture.hub.capturedErrorEvents.first?.request)
#if SDK_V10
        XCTAssertNil(request.headers)
        XCTAssertEqual(request.cookies, ["theme": "dark", "session": "[Filtered]"])
#else
        XCTAssertEqual(request.headers, ["Content-Type": "application/json"])
        XCTAssertNil(request.cookies)
#endif // SDK_V10
    }

    func testCaptureHTTPClientErrorResponse_whenHeadersAreOffAndCookiesEnabled_shouldCollectOnlyCookies() throws {
        // -- Arrange --
#if SDK_V10
        fixture.options.dataCollection.httpHeaders.response = .off
        fixture.options.dataCollection.cookies = .denyList()
#endif // SDK_V10
        let task = createDataTask()
        task.setResponse(try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Set-Cookie": "theme=dark; HttpOnly"
            ]
        )))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let response = try XCTUnwrap(fixture.hub.capturedErrorEvents.first?.context?["response"])
#if SDK_V10
        XCTAssertNil(response["headers"])
        XCTAssertEqual(response["cookies"] as? [String: String], ["theme": "dark"])
#else
        XCTAssertEqual(response["headers"] as? [String: String], ["Content-Type": "application/json"])
        XCTAssertNil(response["cookies"])
#endif // SDK_V10
    }

    func testCaptureHTTPClientError_whenRequestDenyListIsConfigured_shouldNotFilterResponseHeaders() throws {
        // -- Arrange --
#if SDK_V10
        fixture.options.dataCollection.httpHeaders.request = .denyList(terms: ["forwarded"])
#endif // SDK_V10
        let task = createDataTask { request in
            var request = request
            request.allHTTPHeaderFields = ["X-Forwarded-For": "192.0.2.1"]
            return request
        }
        task.setResponse(try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: ["X-Forwarded-For": "192.0.2.2"]
        )))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let event = try XCTUnwrap(fixture.hub.capturedErrorEvents.first)
        let request = try XCTUnwrap(event.request)
        let response = try XCTUnwrap(event.context?["response"])
#if SDK_V10
        XCTAssertEqual(request.headers, ["X-Forwarded-For": "[Filtered]"])
        XCTAssertEqual(response["headers"] as? [String: String], ["X-Forwarded-For": "192.0.2.2"])
#else
        XCTAssertEqual(request.headers, [:])
        XCTAssertEqual(response["headers"] as? [String: String], [:])
#endif // SDK_V10
    }

    func testCaptureHTTPClientError_whenResponseAllowListIsConfigured_shouldNotFilterRequestHeaders() throws {
        // -- Arrange --
#if SDK_V10
        fixture.options.dataCollection.httpHeaders.response = .allowList(terms: ["content-type"])
#endif // SDK_V10
        let task = createDataTask { request in
            var request = request
            request.allHTTPHeaderFields = ["X-Request-Id": "request-id"]
            return request
        }
        task.setResponse(try XCTUnwrap(HTTPURLResponse(
            url: SentryNetworkTrackerTests.fullUrl,
            statusCode: 500,
            httpVersion: "1.1",
            headerFields: [
                "Content-Type": "application/json",
                "X-Request-Id": "response-id"
            ]
        )))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let event = try XCTUnwrap(fixture.hub.capturedErrorEvents.first)
        let request = try XCTUnwrap(event.request)
        let response = try XCTUnwrap(event.context?["response"])
#if SDK_V10
        XCTAssertEqual(request.headers, ["X-Request-Id": "request-id"])
        XCTAssertEqual(response["headers"] as? [String: String], [
            "Content-Type": "application/json",
            "X-Request-Id": "[Filtered]"
        ])
#else
        XCTAssertEqual(request.headers, ["X-Request-Id": "request-id"])
        XCTAssertEqual(response["headers"] as? [String: String], [
            "Content-Type": "application/json",
            "X-Request-Id": "response-id"
        ])
#endif // SDK_V10
    }

    func testCaptureHTTPClientError_whenCookiesAreOff_shouldStillCaptureOrdinaryHeaders() throws {
        // -- Arrange --
#if SDK_V10
        fixture.options.dataCollection.cookies = .off
#endif // SDK_V10
        let task = createDataTask { request in
            var request = request
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json",
                "Cookie": "theme=dark"
            ]
            return request
        }
        task.setResponse(try createResponse(code: 500))

        // -- Act --
        fixture.getSut().urlSessionTask(task, setState: .completed)

        // -- Assert --
        let request = try XCTUnwrap(fixture.hub.capturedErrorEvents.first?.request)
        XCTAssertEqual(request.headers, ["Content-Type": "application/json"])
#if SDK_V10
        XCTAssertEqual(request.cookies, [:])
#else
        XCTAssertNil(request.cookies)
#endif // SDK_V10
    }

    func testCaptureHTTPClientErrorException() throws {
        let sut = fixture.getSut()
        let task = createDataTask()
        task.setResponse(try createResponse(code: 500))

        sut.urlSessionTask(task, setState: .completed)

        XCTAssertEqual(self.fixture.hub.capturedErrorEvents.count, 1, "Expected only one error event to be captured")
        let capturedErrorEvent = try XCTUnwrap(self.fixture.hub.capturedErrorEvents.first)

        let exceptions = try XCTUnwrap(capturedErrorEvent.exceptions)
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

    private func assertStatus(status: SentrySpanStatus, state: URLSessionTask.State, response: URLResponse, configSut: ((TestNetworkTracker) -> Void)? = nil) throws {
        let sut = fixture.getSut()
        configSut?(sut)

        let task = createDataTask()

        let transaction = startTransaction()

        sut.urlSessionTaskResume(task)

        let spans = Dynamic(transaction).children as [Span]?
        let span = try XCTUnwrap(spans?.first)

        task.setResponse(response)

        sut.urlSessionTask(task, setState: state)

        let httpStatusCode = span.data["http.response.status_code"] as? NSNumber

        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual(NSNumber(value: httpResponse.statusCode), httpStatusCode)
        } else {
            XCTAssertNil(httpStatusCode)
        }

        let path = span.data["url"] as? String
        let method = span.data["http.request.method"] as? String
        let requestType = span.data["type"] as? String
        let query = span.data["http.query"] as? String
        let fragment = span.data["http.fragment"] as? String
        let graphql = span.data["graphql_operation_name"] as? String

        #if SDK_V10
        XCTAssertEqual(path, "https://www.domain.com/api?query=value&query2=value2")
#else
        XCTAssertEqual(path, "https://www.domain.com/api")
#endif // SDK_V10
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

    // MARK: - Concurrent resume + setState race (issue #8012)

    func testResumeConcurrentWithSetState_DoesNotCrash() {
        let sut = fixture.getSut()

        let queue = DispatchQueue(label: "resume-setState-race", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let iterations = 500
        let expectation = XCTestExpectation(description: "Concurrent resume and setState")
        expectation.expectedFulfillmentCount = iterations * 2
        expectation.assertForOverFulfill = true

        for _ in 0..<iterations {
            let task = createDataTask()
            _ = startTransaction()

            queue.async {
                sut.urlSessionTaskResume(task)
                expectation.fulfill()
            }
            queue.async {
                task.state = .completed
                sut.urlSessionTask(task, setState: .completed)
                expectation.fulfill()
            }
        }

        queue.activate()
        wait(for: [expectation], timeout: 10)
    }

    func testResumeAfterTaskCompleted_DoesNotCrash() {
        let sut = fixture.getSut()
        let transaction = startTransaction()
        let task = createDataTask()

        task.state = .completed
        sut.urlSessionTaskResume(task)

        let spans = Dynamic(transaction).children as [Span]?
        XCTAssertEqual(spans?.count ?? 0, 0)
    }
}

private final class NetworkTrackerTestSpan: NSObject, Span {
    init(traceId: SentryId = SentryId()) {
        self.traceId = traceId
    }

    var traceId: SentryId
    var spanId = SpanId()
    var parentSpanId: SpanId?
    var sampled: SentrySampleDecision = .undecided
    var operation = "test"
    var origin = "test"
    var spanDescription: String?
    var status: SentrySpanStatus = .undefined
    var timestamp: Date?
    var startTimestamp: Date?
    var data: [String: Any] { [:] }
    var tags: [String: String] { [:] }
    var isFinished: Bool { false }
    var traceContext: TraceContext?

    func startChild(operation: String) -> Span { self }
    func startChild(operation: String, description: String?) -> Span { self }
    func setData(value: Any?, key: String) {}
    func removeData(key: String) {}
    func setTag(value: String, key: String) {}
    func removeTag(key: String) {}
    func setMeasurement(name: String, value: NSNumber) {}
    func setMeasurement(name: String, value: NSNumber, unit: MeasurementUnit) {}
    func finish() {}
    func finish(status: SentrySpanStatus) {}
    func toTraceHeader() -> TraceHeader {
        TraceHeader(trace: traceId, spanId: spanId, sampled: sampled)
    }
    func baggageHttpHeader() -> String? { nil }
    func serialize() -> [String: Any] { [:] }
}
