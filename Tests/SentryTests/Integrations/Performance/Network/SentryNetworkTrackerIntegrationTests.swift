import Sentry
import SwiftUI
import XCTest

class SentryNetworkTrackerIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTests")
    private static let testURL = URL(string: "http://localhost:8080/hello")!
    private static let transactionName = "TestTransaction"
    private static let transactionOperation = "Test"
    
    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerIntegrationTests.dsnAsString
            options.tracesSampleRate = 1.0
        }
        
        var mutableUrlRequest: URLRequest {
            return URLRequest(url: SentryNetworkTrackerIntegrationTests.testURL)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testNSURLSessionConfiguration_NoActiveSpan_NoHeadersAdded() {
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
    
    func testNetworkTrackerDisabled_WhenNetworkTrackingDisabled() {
        testNetworkTrackerDisabled { options in
            options.enableNetworkTracking = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenAutoPerformanceTrackingDisabled() {
        testNetworkTrackerDisabled { options in
            options.enableAutoPerformanceTracking = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenTracingDisabled() {
        testNetworkTrackerDisabled { options in
            options.tracesSampleRate = 0.0
        }
    }
    
    func testNetworkTrackerDisabled_WhenSwizzlingDisabled() {
        testNetworkTrackerDisabled { options in
            options.enableSwizzling = false
        }
    }
    
    func test_TracingAndBreadcrumbsDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableNetworkBreadcrumbs = false
                
        assertRemovedIntegration(options)
    }
    
    func test_SwizzingDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableSwizzling = false
        
        assertRemovedIntegration(options)
    }
    
    func testBreadcrumbDisabled_WhenSwizzlingDisabled() {
        fixture.options.enableSwizzling = false
        startSDK()
        
        XCTAssertFalse(SentryNetworkTracker.sharedInstance.isNetworkBreadcrumbEnabled)
    }
    
    func testBreadcrumbDisabled() {
        fixture.options.enableNetworkBreadcrumbs = false
        startSDK()
        
        XCTAssertFalse(SentryNetworkTracker.sharedInstance.isNetworkBreadcrumbEnabled)
    }
    
    func testBreadcrumbEnabled() {
        startSDK()
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isNetworkBreadcrumbEnabled)
    }
    
    func testNSURLSessionConfiguration_ActiveSpan_HeadersAdded() {
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        
        let transaction = startTransactionBoundToScope()
        let traceState = transaction.traceState
        
        if canHeaderBeAdded() {
            let expected = [SENTRY_TRACE_HEADER: transaction.toTraceHeader().value(), SENTRY_TRACESTATE_HEADER: traceState.toHTTPHeader() ]
            XCTAssertEqual(expected, configuration.httpAdditionalHeaders as! [String: String])
        } else {
            XCTAssertNil(configuration.httpAdditionalHeaders)
        }
    }
    
    func testNSURLSession_TraceHeaderAdded() {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        
        let transaction = SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true) as! SentryTracer
        let traceState = transaction.traceState
        
        let configuration = URLSessionConfiguration.default
        let additionalHeaders = ["test": "SDK"]
        configuration.httpAdditionalHeaders = additionalHeaders
        let session = URLSession(configuration: configuration)
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testURL) { (_, _, _) in
            expect.fulfill()
        }
        
        if canHeaderBeAdded() {
            let expected = [SENTRY_TRACE_HEADER: transaction.toTraceHeader().value(), SENTRY_TRACESTATE_HEADER: traceState.toHTTPHeader()]
                .merging(additionalHeaders) { (current, _) in current }
            XCTAssertEqual(expected, dataTask.currentRequest?.allHTTPHeaderFields)
        } else {
            XCTAssertEqual(additionalHeaders, configuration.httpAdditionalHeaders as! [String: String])
        }
        
        dataTask.resume()
        
        wait(for: [expect], timeout: 5)
    }
    
    /**
     * Reproduces https://github.com/getsentry/sentry-cocoa/issues/1288
     */
    func testCustomURLProtocol_BlocksAllRequests() {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        
        let customConfiguration = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        customConfiguration.protocolClasses?.insert(BlockAllRequestsProtocol.self, at: 0)
        let session = URLSession(configuration: customConfiguration)
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testURL) { (_, _, error) in
            
            if let error = (error as NSError?) {
                XCTAssertEqual(BlockAllRequestsProtocol.error.domain, error.domain)
                XCTAssertEqual(BlockAllRequestsProtocol.error.code, error.code)
            } else {
                XCTFail("Error expected")
            }
            expect.fulfill()
        }
        
        dataTask.resume()
        wait(for: [expect], timeout: 5)
    }
    
    func flaky_testWhenTaskCancelledOrSuspended_OnlyOneBreadcrumb() {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testURL) { (_, _, _) in
            expect.fulfill()
        }
        
        //There is no way to predict what will happen calling this order of events
        dataTask.resume()
        dataTask.suspend()
        dataTask.resume()
        dataTask.cancel()
        
        wait(for: [expect], timeout: 5)
        
        let scope = SentrySDK.currentHub().scope
        let breadcrumbs = Dynamic(scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(1, breadcrumbs?.count)
    }
    
    func testGetRequest_SpanCreatedAndTraceHeaderAdded() {
        startSDK()
        let transaction = SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as! SentryTracer
        let expect = expectation(description: "Request completed")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testURL) { (data, _, _) in
            let response = String(data: data ?? Data(), encoding: .utf8) ?? ""
            
            if self.canHeaderBeAdded() {
                XCTAssertEqual("Hello, world! Trace header added.", response)
            } else {
                XCTAssertEqual("Hello, world!", response)
            }
            
            expect.fulfill()
        }
        
        dataTask.resume()
        wait(for: [expect], timeout: 5)
        
        let children = Dynamic(transaction).children as [Span]?
        
        XCTAssertEqual(children?.count, 1) //Span was created in task resume swizzle.
        let networkSpan = children![0]
        XCTAssertTrue(networkSpan.isFinished) //Span was finished in task setState swizzle.
        XCTAssertEqual(SENTRY_NETWORK_REQUEST_OPERATION, networkSpan.context.operation)
        XCTAssertEqual("GET \(SentryNetworkTrackerIntegrationTests.testURL)", networkSpan.context.spanDescription)
        
        XCTAssertEqual("200", networkSpan.tags["http.status_code"])
    }
    
    private func testNetworkTrackerDisabled(configureOptions: (Options) -> Void) {
        configureOptions(fixture.options)
        
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        _ = startTransactionBoundToScope()
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
        
    /**
     * The header can only be added when we can swizzle URLSessionConfiguration. For more details see
     * SentryNetworkTrackingIntegration#swizzleNSURLSessionConfiguration.
     */
    private func canHeaderBeAdded() -> Bool {
        let selector = NSSelectorFromString("HTTPAdditionalHeaders")
        let classToSwizzle = URLSessionConfiguration.self
        return class_getInstanceMethod(classToSwizzle, selector) != nil
    }
    
    private func startSDK() {
        SentrySDK.start(options: self.fixture.options)
    }
    
    private func startTransactionBoundToScope() -> SentryTracer {
        return SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true) as! SentryTracer
    }
    
    private func assertRemovedIntegration(_ options: Options) {
        let sut = SentryNetworkTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("NetworkTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
}

class BlockAllRequestsProtocol: URLProtocol {
    
    static let error = NSError(domain: "network.issue", code: 10, userInfo: nil)
    
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
            client?.urlProtocol(self, didFailWithError: BlockAllRequestsProtocol.error )
        } else {
            XCTFail("Couldn't block request because client was nil.")
        }
    }

    override func stopLoading() {

    }
}
