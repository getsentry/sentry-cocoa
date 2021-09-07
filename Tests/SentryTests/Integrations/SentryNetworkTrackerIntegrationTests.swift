import XCTest

class SentryNetworkTrackerIntegrationTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTests")
    private static let testURL = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png")!
    private static let transactionName = "TestTransaction"
    private static let transactionOperation = "Test"
    
    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let options: Options
        let nsUrlRequest = NSURLRequest(url: SentryNetworkTrackerIntegrationTests.testURL)
        
        init() {
            options = Options()
            options.dsn = SentryNetworkTrackerIntegrationTests.dsnAsString
        }
        
        var mutableUrlRequest: URLRequest {
            return URLRequest(url: SentryNetworkTrackerIntegrationTests.testURL)
        }
    }
    
    private var fixture = Fixture() 
    
    override func setUp() {
        super.setUp()
        
        SentrySDK.start { options in
            options.dsn = SentryNetworkTrackerIntegrationTests.dsnAsString
            options.tracesSampleRate = 1.0
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testNSURLSessionConfiguration_NoActiveSpan_NoHeadersAdded() {
        let configuration = URLSessionConfiguration.default
        
        XCTAssertNil(configuration.httpAdditionalHeaders)
    }
    
    func testNSURLSessionConfiguration_ActiveSpan_HeadersAdded() {
        let configuration = URLSessionConfiguration.default
        
        let transaction = SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true)
        
        if #available(iOS 14.0, tvOS 14.3, macCatalyst 14.0, macOS 11.0, *) {
            let expected = [SENTRY_TRACE_HEADER: transaction.toTraceHeader().value()]
            XCTAssertEqual(expected, configuration.httpAdditionalHeaders as! [String: String])
        } else {
            XCTAssertNil(configuration.httpAdditionalHeaders)
        }
    }
    
    func testNSURLSession_TraceHeaderAdded() {
        let expect = expectation(description: "Callback Expectation")
        
        let transaction = SentrySDK.startTransaction(name: "Test", operation: "test", bindToScope: true)
        
        let configuration = URLSessionConfiguration.default
        let additionalHeaders = ["test": "SDK"]
        configuration.httpAdditionalHeaders = additionalHeaders
        let session = URLSession(configuration: configuration)
        let dataTask = session.dataTask(with: SentryNetworkTrackerIntegrationTests.testURL) { (_, _, _) in
            expect.fulfill()
        }
        
        if #available(iOS 14.0, tvOS 14.3, macCatalyst 14.0, macOS 11.0, *) {
            let expected = [SENTRY_TRACE_HEADER: transaction.toTraceHeader().value()]
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
    func ignoredTestCustomURLProtocol_BlocksAllRequests() {
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
        wait(for: [expect], timeout: 1)
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
        client?.urlProtocol(self, didFailWithError: BlockAllRequestsProtocol.error )
    }

    override func stopLoading() {

    }
}
