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
            requestManager.returnResponse(response: HTTPURLResponse.init())
            
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
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
    
    func testSendEventOptionsDisabled() {
        options.enabled = false
        sendEvent(callsCompletionHandler: false)
        sendEvent(callsCompletionHandler: false)
        
        XCTAssertEqual(0, requestManager.requests.count)
    }
    
    func testSendAllEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        givenOkResponse()
        sendEnvelope()
        
        XCTAssertEqual(3, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
    
    func testSendAllEventsButNotReady() {
        givenNoInternetConnection()
        sendEnvelope()
        
        requestManager.isReady = false
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        XCTAssertEqual(1, fileManager.getAllStoredEvents().count)
    }
    
    func testSendAllEventsButNotReady2() {
        givenNoInternetConnection()
        sendEnvelope()
        
        givenOkResponse()
        // Rate limit changes between sending the event succesfully
        // and calling sending all events. This can happen when for
        // example when multiple requests run in parallel.
        requestManager.returnResponse(response: {
            self.rateLimits.isLimitRateReached = true
            return HTTPURLResponse.init()
        })
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        XCTAssertEqual(1, fileManager.getAllStoredEvents().count)
    }
    
    func testSendEvent429ResponseUpdatesRateLimit() {
        let response = given429Response()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWith429ResponseUpdatesRateLimit() {
        let response = given429Response()
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testOptionsEnabledButRateLimitReached() {
        rateLimits.isLimitRateReached = true
        
        sendEvent(callsCompletionHandler: false)
        
        XCTAssertEqual(0, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
    
    func testSendEventWithFaultyNSUrlRequest() {
        var completionHandlerWasCalled = false
        sut.send(event: TestConstants.eventWithSerializationError) { (error) in
            XCTAssertNotNil(error)
            XCTAssertTrue(error.debugDescription.contains("SentryErrorDomain"))
            completionHandlerWasCalled = true
        }
        
        XCTAssertTrue(completionHandlerWasCalled)
    }
    
    func testSendOneEnvelope() {
        sendEnvelope()
        
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
    
    
    func testEnvelopeOptionsDisabled() {
        options.enabled = false
        sendEnvelope(callsCompletionHandler: false)
        
        XCTAssertEqual(0, requestManager.requests.count)
    }
    
    private func given429Response() -> HTTPURLResponse {
        let response = HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "1"])!
        requestManager.returnResponse(response: response)
        return response
    }
    
    private func givenNoInternetConnection() {
        requestManager.returnResponse(response: nil)
    }
    
    private func givenOkResponse() {
        requestManager.returnResponse(response: HTTPURLResponse.init())
    }
    
    private func sendEvent(callsCompletionHandler: Bool = true) {
        var completionHandlerWasCalled = false
        sut.send(event: Event()) { (error) in
            XCTAssertNil(error)
            completionHandlerWasCalled = true
        }
        XCTAssertEqual(callsCompletionHandler, completionHandlerWasCalled)
    }
    
    private func sendEnvelope(callsCompletionHandler: Bool = true) {
        var completionHandlerWasCalled = false
        sut.send(envelope: TestConstants.envelope) { (error) in
            XCTAssertNil(error)
            completionHandlerWasCalled = true
        }
        XCTAssertEqual(callsCompletionHandler, completionHandlerWasCalled)
    }
    
    
    private func assertRateLimitUpdated(response: HTTPURLResponse) {
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertEqual(1, rateLimits.responses.count)
        XCTAssertEqual(response, rateLimits.responses[0])
    }
}
