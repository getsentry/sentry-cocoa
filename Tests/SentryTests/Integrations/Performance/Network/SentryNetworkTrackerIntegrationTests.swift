@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// Tests with a running test server to validate our swizzling doesn't break the HTTP requests are in
/// the SentryTestServerTests/SentryNetworkTrackerIntegrationTests.swift
class SentryNetworkTrackerIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTests")
    private static let testBaggageURL = URL(string: "http://localhost:8080/echo-baggage-header")!
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
    
    func testBreadcrumbDisabled() {
        fixture.options.enableNetworkBreadcrumbs = false
        startSDK()
        
        XCTAssertFalse((try? getNetworkTracker()?.isNetworkBreadcrumbEnabled) ?? true)
    }
    
    func testBreadcrumbEnabled() {
        startSDK()
        XCTAssertTrue((try? getNetworkTracker()?.isNetworkBreadcrumbEnabled) ?? false)
    }
    
    /**
     * Reproduces https://github.com/getsentry/sentry-cocoa/issues/1288
     */
    func testCustomURLProtocol_BlocksAllRequests() throws {
        startSDK()
        
        let expect = expectation(description: "Callback Expectation")
        
        let customConfiguration = try XCTUnwrap(URLSessionConfiguration.default.copy() as? URLSessionConfiguration)
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
    
    func testCaptureFailedRequestsEnabled() {
        startSDK()

        XCTAssertTrue((try? getNetworkTracker()?.isCaptureFailedRequestsEnabled) ?? false)
    }
    
    func testCaptureFailedRequestsDisabled() {
        fixture.options.enableCaptureFailedRequests = false
        startSDK()

        XCTAssertFalse((try? getNetworkTracker()?.isCaptureFailedRequestsEnabled) ?? true)
    }

    func testGraphQLOperationTrackingEnabled() {
        fixture.options.enableGraphQLOperationTracking = true
        startSDK()

        XCTAssertTrue((try? getNetworkTracker()?.isGraphQLOperationTrackingEnabled) ?? false)
    }

    func testGraphQLOperationTrackingDisabled() {
        startSDK()

        XCTAssertFalse((try? getNetworkTracker()?.isGraphQLOperationTrackingEnabled) ?? true)
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
    
    private func getNetworkTracker() throws -> SentryNetworkTracker? {
        let integration = SentrySDKInternal.currentHub().getInstalledIntegration(SentryNetworkTrackingIntegration<SentryDependencyContainer>.self) as? SentryNetworkTrackingIntegration<SentryDependencyContainer>

        return integration?.getNetworkTracker()
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
