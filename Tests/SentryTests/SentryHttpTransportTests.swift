import XCTest

class SentryHttpTransportTests: XCTestCase {

    private var fileManager: SentryFileManager!
    private var options: Options!
    private var requestManager: TestRequestManager!
    private var currentDateProvider: TestCurrentDateProvider!
    private var rateLimits: TestRateLimits!
    private var sut: SentryHttpTransport!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
        do {
            fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
            
            requestManager = TestRequestManager(session: URLSession())
            options = try Options(dict: ["dsn": TestConstants.dsnAsString])
            rateLimits = TestRateLimits()
            
            sut = SentryHttpTransport(
                options: options,
                sentryFileManager: fileManager,
                sentryRequestManager: requestManager,
                sentryRateLimits: rateLimits
            )
        } catch {
            XCTFail("SentryHttpTransport could not be created")
        }
    }
    
    override func tearDown() {
        fileManager.deleteAllStoredEvents()
    }

    func testSendOneEvent()  {
        sendEvent()
        
        XCTAssertEqual(1, requestManager.requests.count)
    }
    
    func testOptionsDisabled() {
        options.enabled = false
        sendEvent()
        sendEvent()
        
        XCTAssertEqual(0, requestManager.requests.count)
    }
    
    func test429ResponseUpdatesRateLimit() {
        let response = createRetryAfterHeader(headerValue: "1")
        requestManager.returnResponse(response: response)
        
        // First response parses Retry-After header
        sendEvent()
        
        XCTAssertEqual(1, rateLimits.responses.count)
        XCTAssertEqual(response, rateLimits.responses[0])
    }
    
    func testOptionsEnabledButRateLimitReached() {
        rateLimits.isLimitRateReached = true
        
        sendEvent()
        
        XCTAssertEqual(0, requestManager.requests.count)
    }
  
    private func sendEvent() {
        sut.send(event: Event(), completion: nil)
    }
    
    private func createRetryAfterHeader(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": headerValue])!
    }
}
