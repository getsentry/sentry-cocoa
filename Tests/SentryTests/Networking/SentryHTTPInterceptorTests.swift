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
        let request: URLRequest!
        let options: Options
        
        init() {
            options = Options()
            options.dsn = SentryHTTPInterceptorTests.dsnAsString
            
            scope = Scope()
            client = TestClient(options: options)!
            span = SentrySpan(context: SpanContext(operation: "SomeOperation"))
            hub = TestHub(client: client, andScope: scope)
            scope.span = span
            request = URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!)
        }
        
        func getSut() -> URLRequest? {
            return SentryNetworkTracker.sharedInstance.initializeUrlRequest(URLRequest(url: URL(string: SentryHTTPInterceptorTests.httpUrl)!))
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        SentrySDK.setCurrentHub(fixture.hub)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInterception() {
        let sut = fixture.getSut()!
        XCTAssertNotNil(sut.value(forHTTPHeaderField: SENTRY_TRACE_HEADER))
    }
    
}
