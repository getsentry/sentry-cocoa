import XCTest

class SentryHTTPInterceptorTests: XCTestCase {
    
    private class Fixture {
        let client: TestClient
        let hub: TestHub
        let scope: Scope
        let span: Span
        let request: URLRequest! = nil
        
        init() {
            scope = Scope()
            client = TestClient(options: Options())!
            span = SentrySpan(context: SpanContext(operation: "SomeOperation"))
            hub = TestHub(client: client, andScope: scope)
            scope.span = span
        }
        
        func getSut() -> SentryHttpInterceptor {
            return SentryHttpInterceptor(request: request, cachedResponse: nil, client: nil)
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
        SentrySDK.setCurrentHub(nil)
    }
    
    
    func testSessionConfiguration(){
        let configuration = URLSessionConfiguration()
        
        XCTAssertNil(configuration.protocolClasses)
        SentryHttpInterceptor.configureSessionConfiguration(configuration)
        XCTAssertEqual(configuration.protocolClasses?.count, 1)
        XCTAssertTrue(configuration.protocolClasses?.first === SentryHttpInterceptor.self)
    }
    
    func testCanInitWithRequestHTTP(){
        let request = URLRequest(url: URL(string:"http://somedomain.com")!)
        XCTAssertTrue(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCanInitWithRequestHTTPS(){
        let request = URLRequest(url: URL(string:"https://somedomain.com")!)
        XCTAssertTrue(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCannotInitWithRequestWS(){
        let request = URLRequest(url: URL(string:"ws://somedomain.com")!)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: request))
    }
    
    func testCannotInitWithoutScopeTransaction(){
        fixture.scope.span = nil
        let request = URLRequest(url: URL(string:"ws://somedomain.com")!)
        XCTAssertFalse(SentryHttpInterceptor.canInit(with: request))
    }
    
    
}
