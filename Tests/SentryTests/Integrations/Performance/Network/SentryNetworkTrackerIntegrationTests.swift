@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

/// Tests with a running test server to validate our swizzling doesn't break the HTTP requests are in
/// the SentryTestServerTests/SentryNetworkTrackerIntegrationTests.swift
class SentryNetworkTrackerIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTests")
    private static let testBaggageURL = URL(string: "http://localhost:8081/echo-baggage-header")!
    private static let transactionName = "TestTransaction"
    private static let transactionOperation = "Test"
    
    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerIntegrationTests.dsnAsString
            options.tracesSampleRate = 1.0
            options.removeAllIntegrations()
            options.enableNetworkTracking = true
            options.enableNetworkBreadcrumbs = true
            options.enableCaptureFailedRequests = true
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    func testNSURLSessionConfiguration_NoActiveSpan_NoHeadersAdded() {
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
    
    func testNetworkTrackerDisabled_WhenNetworkTrackingDisabled() throws {
        try assertNetworkTrackerDisabled { options in
            options.enableNetworkTracking = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenAutoPerformanceTrackingDisabled() throws {
        try assertNetworkTrackerDisabled { options in
            options.enableAutoPerformanceTracing = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenTracingDisabled() throws {
        try assertNetworkTrackerDisabled { options in
            options.tracesSampleRate = 0.0
        }
    }
    
    func testNetworkTrackerDisabled_WhenSwizzlingDisabled() throws {
        try assertNetworkTrackerDisabled { options in
            options.enableSwizzling = false
        }
    }
    
    func test_TracingAndBreadcrumbsDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false
                
        assertIntegrationNotInstalled(options)
    }
    
    func test_SwizzingDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableSwizzling = false
        
        assertIntegrationNotInstalled(options)
    }
    
    func testBreadcrumbDisabled_WhenSwizzlingDisabled() {
        fixture.options.enableSwizzling = false
        startSDK()
        
        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkBreadcrumbEnabled)
    }
    
    func testBreadcrumbDisabled() {
        fixture.options.enableNetworkBreadcrumbs = false
        startSDK()
        
        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkBreadcrumbEnabled)
    }
    
    func testBreadcrumbEnabled() {
        startSDK()
        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkBreadcrumbEnabled)
    }
    
    /**
     * Reproduces https://github.com/getsentry/sentry-cocoa/issues/1288
     */
    func testURLSession_whenCustomURLProtocolBlocksRequest_shouldExecuteProtocol() throws {
#if !os(watchOS)
        // -- Arrange --
        startSDK()
        let requestBlocked = expectation(description: "Custom URL protocol blocked request")
        BlockAllRequestsProtocol.onRequestBlocked.withLock {
            $0 = { requestBlocked.fulfill() }
        }
        defer {
            BlockAllRequestsProtocol.onRequestBlocked.withLock { $0 = nil }
        }

        let customConfiguration = try XCTUnwrap(URLSessionConfiguration.default.copy() as? URLSessionConfiguration)
        customConfiguration.protocolClasses?.insert(BlockAllRequestsProtocol.self, at: 0)
        let session = URLSession(configuration: customConfiguration)
        defer { session.invalidateAndCancel() }
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testBaggageURL)

        // -- Act --
        dataTask.resume()

        // -- Assert --
        wait(for: [requestBlocked], timeout: 30)
#else
        throw XCTSkip("Test is disabled for watchOS")
#endif
    }
    
    private func flaky_testWhenTaskCancelledOrSuspended_OnlyOneBreadcrumb() {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testBaggageURL) { (_, _, error) in
            self.assertNetworkError(error)
            expect.fulfill()
        }
        
        //There is no way to predict what will happen calling this order of events
        dataTask.resume()
        dataTask.suspend()
        dataTask.resume()
        dataTask.cancel()
        
        wait(for: [expect], timeout: 5)
        
        let scope = SentrySDKInternal.currentHub().scope
        let breadcrumbs = Dynamic(scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(1, breadcrumbs?.count)
    }

    /// Runs a real request through our `resume` and `setState:` swizzles, which now take an
    /// autoreleased reference to the task, and verifies the swizzled path still records a network
    /// breadcrumb. A custom URLProtocol answers offline so the request completes deterministically.
    /// The breadcrumb is recorded on the terminal `setState:` transition, which runs on a CFNetwork
    /// thread that is not synchronized with the completion handler, so this polls for it. Its exact
    /// count and data are platform dependent (the SDK swizzles more than one task class on iOS), so
    /// this only asserts that a network breadcrumb was recorded.
    func testResume_whenRequestCompletes_recordsHTTPBreadcrumb() throws {
        // -- Arrange --
        startSDK()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RespondingRequestProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let url = try XCTUnwrap(URL(string: "https://request.test/ok"))
        let completed = expectation(description: "Task completed")
        let task = session.dataTask(with: url) { _, _, _ in completed.fulfill() }

        // -- Act --
        task.resume()
        wait(for: [completed], timeout: 5)

        // -- Assert --
        let scope = SentrySDKInternal.currentHub().scope
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var httpBreadcrumbCount = 0
        repeat {
            let breadcrumbs = (Dynamic(scope).breadcrumbArray as [Breadcrumb]?) ?? []
            httpBreadcrumbCount = breadcrumbs.filter { $0.category == "http" }.count
            if httpBreadcrumbCount > 0 {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        } while ProcessInfo.processInfo.systemUptime < deadline
        XCTAssertGreaterThan(httpBreadcrumbCount, 0)
    }

    /// Verifies the lifetime fix balances its retain: the `resume`/`setState:` swizzles take an
    /// autoreleased reference to the task, so once the task completes and the autorelease pool
    /// drains, the task is deallocated rather than leaked. A regression that retained without
    /// autoreleasing would keep `weakTask` alive here.
    func testResumeThenCancel_whenSwizzled_doesNotLeakTask() throws {
        // -- Arrange --
        startSDK()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingRequestProtocol.self]
        let session = URLSession(configuration: configuration)

        let url = try XCTUnwrap(URL(string: "https://request.test/hang"))
        weak var weakTask: URLSessionTask?

        // -- Act --
        autoreleasepool {
            let completed = expectation(description: "Task completed")
            let task = session.dataTask(with: url) { _, _, _ in completed.fulfill() }
            weakTask = task
            task.resume()
            task.cancel()
            wait(for: [completed], timeout: 5)
        }

        // -- Assert --
        // Invalidate so the session drops its own reference to the finished task.
        session.invalidateAndCancel()
        // The terminal setState: transition autoreleases the task on a CFNetwork thread whose pool
        // this test does not drain, so deallocation can lag completion. Poll instead of asserting
        // immediately; an unbalanced retain never releases and fails this wait. A short interval
        // avoids busy-spinning and the ~1s penalty of XCTNSPredicateExpectation.
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while weakTask != nil && ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertNil(weakTask)
    }

    func testCaptureFailedRequestsDisabled_WhenSwizzlingDisabled() {
        fixture.options.enableSwizzling = false
        fixture.options.enableCaptureFailedRequests = true
        startSDK()

        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isCaptureFailedRequestsEnabled)
    }
    
    func testCaptureFailedRequestsEnabled() {
        startSDK()

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isCaptureFailedRequestsEnabled)
    }
    
    func testCaptureFailedRequestsDisabled() {
        fixture.options.enableCaptureFailedRequests = false
        startSDK()

        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isCaptureFailedRequestsEnabled)
    }

    func testGraphQLOperationTrackingEnabled() {
        fixture.options.enableGraphQLOperationTracking = true
        startSDK()

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isGraphQLOperationTrackingEnabled)
    }

    func testGraphQLOperationTrackingDisabled() {
        startSDK()

        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isGraphQLOperationTrackingEnabled)
    }
    
    private func assertNetworkTrackerDisabled(configureOptions: (Options) -> Void) throws {
        configureOptions(fixture.options)
        
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        _ = try startTransactionBoundToScope()
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
        
    private func startSDK() {
        // Closing the SDK sets enabled to false
        fixture.options.enabled = true
        SentrySDK.start(options: self.fixture.options)
    }
    
    private func startTransactionBoundToScope() throws -> SentryTracer {
        return try XCTUnwrap(SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true) as? SentryTracer)
    }
    
    private func assertIntegrationNotInstalled(_ options: Options) {
        let dependencies = SentryDependencyContainer.sharedInstance()
        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: dependencies)

        XCTAssertNil(sut)
    }
    
    private func assertNetworkError(_ error: Error?) {
        if error != nil {
            XCTFail("Failed to complete request : \(String(describing: error))")
        }
    }
}

class BlockAllRequestsProtocol: URLProtocol {
    
    static let error = NSError(domain: "network.issue", code: 10, userInfo: nil)
    static let onRequestBlocked = SentryMutex<(() -> Void)?>(nil)
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if client != nil {
            client?.urlProtocol(self, didFailWithError: BlockAllRequestsProtocol.error)
            let onRequestBlocked = BlockAllRequestsProtocol.onRequestBlocked.withLock { $0 }
            onRequestBlocked?()
        } else {
            XCTFail("Couldn't block request because client was nil.")
        }
    }

    override func stopLoading() {

    }
}

/// Keeps every request in flight without ever completing it, so the task stays in the `running`
/// state until it is cancelled. Cancelling then drives the `running -> canceling` transition used by
/// the tests above, entirely offline.
class HangingRequestProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Intentionally empty: never notify the client so the request stays in flight until cancel.
    }

    override func stopLoading() {

    }
}

/// Answers every request offline with a 200 response and an empty body, so the task completes
/// through a single `running -> completed` transition without touching the network.
class RespondingRequestProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let client, let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else {
            return
        }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: Data())
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {

    }
}
