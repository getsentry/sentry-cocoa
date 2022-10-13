import Sentry
import SwiftUI
import XCTest

class SentryNetworkTrackerIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTests")
    private static let testBaggageURL = URL(string: "http://localhost:8080/echo-baggage-header")!
    private static let testTraceURL = URL(string: "http://localhost:8080/echo-sentry-trace")!
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
        asserrtNetworkTrackerDisabled { options in
            options.enableNetworkTracking = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenAutoPerformanceTrackingDisabled() {
        asserrtNetworkTrackerDisabled { options in
            options.enableAutoPerformanceTracking = false
        }
    }
    
    func testNetworkTrackerDisabled_WhenTracingDisabled() {
        asserrtNetworkTrackerDisabled { options in
            options.tracesSampleRate = 0.0
        }
    }
    
    func testNetworkTrackerDisabled_WhenSwizzlingDisabled() {
        asserrtNetworkTrackerDisabled { options in
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
    
    /**
     * Reproduces https://github.com/getsentry/sentry-cocoa/issues/1288
     */
    func testCustomURLProtocol_BlocksAllRequests() {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        
        let customConfiguration = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        customConfiguration.protocolClasses?.insert(BlockAllRequestsProtocol.self, at: 0)
        let session = URLSession(configuration: customConfiguration)
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testBaggageURL) { (_, _, error) in
            
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
        
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testBaggageURL) { (_, _, _) in
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
    
    func testGetRequest_SpanCreatedAndBaggageHeaderAdded_disabled() {
        startSDK()
        let transaction = SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as! SentryTracer
        let expect = expectation(description: "Request completed")
        let session = URLSession(configuration: URLSessionConfiguration.default)

        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testBaggageURL) { (data, _, _) in
            let response = String(data: data ?? Data(), encoding: .utf8) ?? ""
            
            let expectedBaggageHeader = transaction.traceContext.toBaggage().toHTTPHeader()
            XCTAssertEqual(expectedBaggageHeader, response)

            expect.fulfill()
        }
        
        dataTask.resume()
        wait(for: [expect], timeout: 5)
        
        let children = Dynamic(transaction).children as [Span]?
        
        XCTAssertEqual(children?.count, 1) //Span was created in task resume swizzle.
        let networkSpan = children![0]
        XCTAssertTrue(networkSpan.isFinished) //Span was finished in task setState swizzle.
        XCTAssertEqual(SENTRY_NETWORK_REQUEST_OPERATION, networkSpan.context.operation)
        XCTAssertEqual("GET \(SentryNetworkTrackerIntegrationTests.testBaggageURL)", networkSpan.context.spanDescription)
        
        XCTAssertEqual("200", networkSpan.tags["http.status_code"])
    }
    
    func testGetRequest_CompareSentryTraceHeader() {
        startSDK()
        let transaction = SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as! SentryTracer
        let expect = expectation(description: "Request completed")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var response: String?
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testTraceURL) { (data, _, _) in
            response = String(data: data ?? Data(), encoding: .utf8) ?? ""
            expect.fulfill()
        }
        
        dataTask.resume()
        wait(for: [expect], timeout: 5)
        
        let children = Dynamic(transaction).children as [SentrySpan]?
        
        XCTAssertEqual(children?.count, 1) //Span was created in task resume swizzle.
        let networkSpan = children![0]

        let expectedTraceHeader = networkSpan.toTraceHeader().value()
        XCTAssertEqual(expectedTraceHeader, response)
    }
    
    private func asserrtNetworkTrackerDisabled(configureOptions: (Options) -> Void) {
        configureOptions(fixture.options)
        
        startSDK()
        
        let configuration = URLSessionConfiguration.default
        _ = startTransactionBoundToScope()
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
        
    private func startSDK() {
        SentrySDK.start(options: self.fixture.options)
    }
    
    private func startTransactionBoundToScope() -> SentryTracer {
        return SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true) as! SentryTracer
    }
    
    private func assertRemovedIntegration(_ options: Options) {
        let sut = SentryNetworkTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
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
