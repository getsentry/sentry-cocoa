import XCTest

class SentryHttpTransportTests: XCTestCase {
    
    private var fileManager: SentryFileManager!
    private var options: Options!
    private var requestManager: TestRequestManager!
    private var currentDateProvider: TestCurrentDateProvider!
    private var rateLimits: DefaultRateLimits!
    private var sut: SentryHttpTransport!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
        do {
            fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
            
            requestManager = TestRequestManager(session: URLSession())
            requestManager.returnResponse(response: HTTPURLResponse.init())
            
            options = try Options(dict: ["dsn": TestConstants.dsnAsString])
            
            rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())
            
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
        
        assertOneRequestSent()
    }
    
    func testSendEventOptionsDisabled() {
        options.enabled = false
        sendEvent(callsCompletionHandler: false)
        sendEvent(callsCompletionHandler: false)
        
        assertNoRequestSent()
    }
    
    func testSendEventWhenSessionRateLimitActive() {
        rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key"))
        
        sendEvent()
        
        assertOneRequestSent()
    }
    
    func testSendAllEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        //TODO: apply RateLimits also to Envelope and sending events after they have been stored.
        givenRateLimitResponse()
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
            self.rateLimits.update(TestResponseFactory.createRetryAfterResponse(headerValue: "1"))
            return HTTPURLResponse.init()
        })
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        XCTAssertEqual(1, fileManager.getAllStoredEvents().count)
    }
    
    func testSendEventWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEventWithRateLimitResponse() {
        let response = givenRateLimitResponse()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRateLimitResponse() {
        let response = givenRateLimitResponse()
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testRateLimitForEvent() {
        givenActiveRateLimitForEvent()
        
        sendEvent(callsCompletionHandler: false)
        
        assertNoRequestSent()
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent(callsCompletionHandler: false)
        
        assertNoRequestSent()
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()
        
        assertOneRequestSent()
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
        
        assertOneRequestSent()
    }
    
    func testEnvelopeOptionsDisabled() {
        options.enabled = false
        sendEnvelope(callsCompletionHandler: false)
        
        assertNoRequestSent()
    }
    
    private func givenRetryAfterResponse() -> HTTPURLResponse {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        requestManager.returnResponse(response: response)
        return response
    }
    
    @discardableResult private func givenRateLimitResponse() -> HTTPURLResponse {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key")
        requestManager.returnResponse(response: response)
        return response
    }
    
    private func givenNoInternetConnection() {
        requestManager.returnResponse(response: nil)
    }
    
    private func givenOkResponse() {
        requestManager.returnResponse(response: HTTPURLResponse.init())
    }
    
    private func givenActiveRateLimitForEvent() {
           rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeEvent):key"))
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
        XCTAssertTrue(rateLimits.isRateLimitActive(SentryEnvelopeItemTypeSession))
    }
    
    private func assertOneRequestSent() {
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
    
    private func assertNoRequestSent() {
        XCTAssertEqual(0, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEvents().count)
    }
}
