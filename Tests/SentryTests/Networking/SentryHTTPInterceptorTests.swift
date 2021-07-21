import XCTest

class SentryHTTPInterceptorTests: XCTestCase {
    
    private static let httpUrl = "http://somedomain.com"
    private static let httpsUrl = "https://somedomain.com"
    private static let wsUrl = "ws://somedomain.com"
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    class TestURLSession: URLSession {
        var invalidateAndCancelDate: Date?
        var lastDataTask: URLSessionDataTaskMock?
        
        override func dataTask(with request: URLRequest) -> URLSessionDataTask {
            lastDataTask = URLSessionDataTaskMock(request: request)
            return lastDataTask!
        }
        
        override func invalidateAndCancel() {
            invalidateAndCancelDate = CurrentDate.date()
        }
    }
    
    class TestSentryHTTPInterceptor: SentryHttpInterceptor {
        override func createSession() -> URLSession {
            return TestURLSession()
        }
    }
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        let span: Span
        let request: URLRequest!
        let options: Options
        let dateProvider = TestCurrentDateProvider()
        
        init() {
            options = Options()
            options.dsn = SentryHTTPInterceptorTests.dsnAsString
            
            scope = Scope()
            client = TestClient(options: options)!
            span = SentrySpan(context: SpanContext(operation: "SomeOperation"))
            hub = TestHub(client: client, andScope: scope)
            scope.span = span
            request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
            CurrentDate.setCurrentDateProvider(dateProvider)
        }
        
        func getSut() -> SentryHttpInterceptor {
            return TestSentryHTTPInterceptor(request: request, cachedResponse: nil, client: TestProtocolClient())
        }
    }
    
    private class AlternativeTestProtocol: URLProtocol {
        
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        SentrySDK.setCurrentHub(nil)
    }
    
    func testSessionConfiguration() {
        let configuration = URLSessionConfiguration()
        
        XCTAssertNil(configuration.protocolClasses)
        SentryHttpInterceptor.configureSessionConfiguration(configuration)
        XCTAssertEqual(configuration.protocolClasses?.count, 1)
        XCTAssertTrue(configuration.protocolClasses?.first === SentryHttpInterceptor.self)
    }
    
    func testSessionConfigurationWithOtherProtocol() {
        let configuration = URLSessionConfiguration()
        configuration.protocolClasses = [AlternativeTestProtocol.self]
        SentryHttpInterceptor.configureSessionConfiguration(configuration)
        XCTAssertTrue(configuration.protocolClasses?.first === SentryHttpInterceptor.self)
    }
    
    func testCanInitWithRequestHTTP() {
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
        XCTAssertTrue(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCanInitWithRequestHTTPS() {
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpsUrl)!)
        XCTAssertTrue(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCannotInitWithRequestWS() {
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.wsUrl)!)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCannotInitWithSentryRequest() {
        let request = URLRequest(url: URL(string: fixture.options.dsn!)!)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCannotInitWithoutScopeTransaction() {
        fixture.scope.span = nil
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpsUrl)!)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCanonicalRequestForRequest() {
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
        let newRequest = SentryHttpInterceptor.canonicalRequest(for: request)
        
        let spanHeader = fixture.span.toTraceHeader()
        XCTAssertNotEqual(request, newRequest)
        XCTAssertEqual(spanHeader.value(), newRequest.value(forHTTPHeaderField: SENTRY_TRACE_HEADER))
        
        let interceptFlag = URLProtocol.property(forKey: SENTRY_INTERCEPTED_REQUEST, in: newRequest) as? NSNumber
        
        XCTAssertTrue(interceptFlag!.boolValue)
    }
    
    func testCanonicalRequestForRequestWithoutTransaction() {
        fixture.scope.span = nil
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
        let newRequest = SentryHttpInterceptor.canonicalRequest(for: request)
        
        XCTAssertEqual(request, newRequest)
        XCTAssertNil(newRequest.value(forHTTPHeaderField: SENTRY_TRACE_HEADER))
    }
    
    func testIgnoreAlreadyInterceptedRequest() {
        let request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
        let newRequest = SentryHttpInterceptor.canonicalRequest(for: request)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: newRequest))
    }
    
    func testProtocolGetRegisteredAndUnregistered() {
        NSURLProtocolSwizzle.swizzleURLProtocol()
        NSURLProtocolSwizzle.shared.registerCallback = { protocolClass in
            XCTAssertTrue(protocolClass === SentryHttpInterceptor.self)
        }
        NSURLProtocolSwizzle.shared.unregisterCallback = { protocolClass in
            XCTAssertTrue(protocolClass === SentryHttpInterceptor.self)
        }
        let integration = SentryNetworkTrackingIntegration()
        integration.install(with: fixture.options)
        integration.uninstall()
        
        NSURLProtocolSwizzle.shared.registerCallback = nil
        NSURLProtocolSwizzle.shared.unregisterCallback = nil
    }
    
    func testProtocolDontGetRegistered() {
        NSURLProtocolSwizzle.swizzleURLProtocol()
        NSURLProtocolSwizzle.shared.registerCallback = { _ in
            XCTAssert(false)
        }
        let integration = SentryNetworkTrackingIntegration()
        fixture.options.enableAutoPerformanceTracking = false
        integration.install(with: fixture.options)
        integration.uninstall()
    }
    
    func testCreateSession() {
        let interceptor = SentryHttpInterceptor(request: fixture.request, cachedResponse: nil, client: nil)
        let session = interceptor.createSession()
        XCTAssertNotNil(session)
        XCTAssertTrue(session.delegate === interceptor)
    }
    
    func testStartLoading() {
        let now = Date()
        fixture.dateProvider.setDate(date: now)
        
        let sut = fixture.getSut()
        sut.startLoading()
        let session = sut.session as? TestURLSession
        
        XCTAssertEqual(session?.lastDataTask?.resumeDate, now)
    }
    
    func testStopLoading() {
        let now = Date()
        fixture.dateProvider.setDate(date: now)
        
        let sut = fixture.getSut()
        sut.startLoading()
        let session = sut.session as? TestURLSession
        sut.stopLoading()
        
        XCTAssertEqual(session?.invalidateAndCancelDate, now)
        XCTAssertNil(sut.session)
    }
    
    func testTaskCompletionWithoutError() {
        let sut = fixture.getSut()
        let session = sut.createSession()
        let client = sut.client as? TestProtocolClient
        client?.testCallback = { method, params in
            XCTAssertEqual(method, "urlProtocolDidFinishLoading:")
            XCTAssertEqual(sut, params["urlProtocol"] as? URLProtocol)
        }
        sut.urlSession(session, task: URLSessionDataTaskMock(), didCompleteWithError: nil)
    }
    
    func testTaskCompletionWithError() {
        let sut = fixture.getSut()
        let session = sut.createSession()
        let client = sut.client as? TestProtocolClient
        let someError = NSError(domain: "errorDomain", code: -1, userInfo: nil)
        client?.testCallback = { method, params in
            XCTAssertEqual(method, "urlProtocol:didFailWithError:")
            XCTAssertEqual(sut, params["urlProtocol"] as? URLProtocol)
            XCTAssertEqual(someError, params["didFailWithError"] as? NSError)
        }
        sut.urlSession(session, task: URLSessionDataTaskMock(), didCompleteWithError: someError)
    }
    
    func testTaskDidReceiveResponse() {
        let sut = fixture.getSut()
        let session = sut.createSession()
        let client = sut.client as? TestProtocolClient
        let response = URLResponse()
        client?.testCallback = { method, params in
            XCTAssertEqual(method, "urlProtocol:didReceive:cacheStoragePolicy:")
            XCTAssertEqual(sut, params["urlProtocol"] as? URLProtocol)
            XCTAssertEqual(response, params["didReceive"] as? URLResponse)
            XCTAssertEqual(URLCache.StoragePolicy.notAllowed, params["cacheStoragePolicy"] as? URLCache.StoragePolicy)
        }
        sut.urlSession(session, dataTask: URLSessionDataTaskMock(), didReceive: response) { disposition in
            XCTAssertEqual(disposition, .allow)
        }
    }
    
    func testDataTaskDidReceiveData() {
        let sut = fixture.getSut()
        let session = sut.createSession()
        let client = sut.client as? TestProtocolClient
        let data = Data()
        client?.testCallback = { method, params in
            XCTAssertEqual(method, "urlProtocol:didLoad:")
            XCTAssertEqual(sut, params["urlProtocol"] as? URLProtocol)
            XCTAssertEqual(data, params["didLoad"] as? Data)
        }
        sut.urlSession(session, dataTask: URLSessionDataTaskMock(), didReceive: data)
    }
}
