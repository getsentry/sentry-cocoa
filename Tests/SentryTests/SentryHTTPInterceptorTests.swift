import XCTest

class SentryHTTPInterceptorTests: XCTestCase {
    
    private static let httpUrl = "http://somedomain.com"
    private static let httpsUrl = "https://somedomain.com"
    private static let wsUrl = "ws://somedomain.com"
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
        
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        let span: Span
        let request: URLRequest! = nil
        let options: Options
        
        init() {
            options = Options()
            options.dsn = SentryHTTPInterceptorTests.dsnAsString
            
            scope = Scope()
            client = TestClient(options: options)!
            span = SentrySpan(context: SpanContext(operation: "SomeOperation"))
            hub = TestHub(client: client, andScope: scope)
            scope.span = span
        }
        
        func getSut() -> SentryHttpInterceptor {
            return SentryHttpInterceptor(request: request, cachedResponse: nil, client: nil)
        }
    }
    
    private class TestProtocol: URLProtocol {
        
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
        configuration.protocolClasses = [TestProtocol.self]
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
    
}
