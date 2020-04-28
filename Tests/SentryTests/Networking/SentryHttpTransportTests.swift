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
        fileManager.deleteAllStoredEventsAndEnvelopes()
    }
    
    func testInitSendsCachedEventsAndEnvelopes() {
        givenNoInternetConnection()
        sendEvent()
        assertEventsStored(eventCount: 1)
        
        givenOkResponse()
        _ = SentryHttpTransport(
            options: options,
            sentryFileManager: fileManager,
            sentryRequestManager: requestManager,
            sentryRateLimits: rateLimits
        )
        
        assertEventsStored(eventCount: 0)
        assertRequestsSent(requestCount: 2)
    }
    
    func testSendOneEvent()  {
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendEventOptionsDisabled() {
        options.enabled = false
        sendEvent(callsCompletionHandler: false)
        sendEvent(callsCompletionHandler: false)
        
        assertRequestsSent(requestCount: 0)
    }
    
    func testSendEventWhenSessionRateLimitActive() {
        rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key"))
        
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendAllEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        givenRateLimitResponse(forType: SentryEnvelopeItemTypeSession)
        sendEnvelope()
        
        XCTAssertEqual(3, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEventsAndEnvelopes().count)
    }
    
    func testSendAllEventsSendsEnvelopes() {
        givenNoInternetConnection()
        let envelope = SentryEnvelope(session: SentrySession())
        sendEnvelope(envelope: envelope)
        sendEnvelope()
        
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(5, requestManager.requests.count)
        XCTAssertEqual(0, fileManager.getAllStoredEventsAndEnvelopes().count)
    }
    
    func testSendAllEventsButNotReady() {
        givenNoInternetConnection()
        sendEnvelope()
        
        requestManager.isReady = false
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        XCTAssertEqual(1, fileManager.getAllStoredEventsAndEnvelopes().count)
    }
    
    func testSendAllEventsButRateLimitIsActive() {
        givenNoInternetConnection()
        sendEvent()
        
        // Rate limit changes between sending the event succesfully
        // and calling sending all events. This can happen when for
        // example when multiple requests run in parallel.
        givenRateLimitResponse(forType: SentryEnvelopeItemTypeEvent)
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        assertEventsStored(eventCount: 0)
    }
    
    func testRateLimitGetsActiveWhileSendAllEvents() {
        givenNoInternetConnection()
        sendEvent()
        sendEvent()
        sendEvent()
        
        // 3 events are saved in the FileManager
        // The first event is sent normally and triggers sendAllEvents.
        // The first stored event from the FileManager gets sent and the response
        // contains a rate limit.
        // Now 2 events are still to be sent, but they get discarded cause of the
        // active rate limit.
        givenFirstRateLimitGetsActiveWithSecondResponse()
        sendEvent()
        
        XCTAssertEqual(5, requestManager.requests.count)
        assertEventsStored(eventCount: 0)
    }
    
    func testSendAllEventsAllEventsDeletedWhenNotReady() {
        givenNoInternetConnection()
        sendEvent()
        sendEvent()
        assertEventsStored(eventCount: 2)
        
        givenRateLimitResponse(forType: SentryEnvelopeItemTypeEvent)
        sendEvent()
        assertEventsStored(eventCount: 0)
    }
    
    func testSendEventWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEventWithRateLimitResponse() {
        let response = givenRateLimitResponse(forType: SentryEnvelopeItemTypeSession)
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRateLimitResponse() {
        let response = givenRateLimitResponse(forType: SentryEnvelopeItemTypeSession)
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testRateLimitForEvent() {
        givenRateLimitResponse(forType: SentryEnvelopeItemTypeEvent)

        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent(callsCompletionHandler: false)
        
        assertRequestsSent(requestCount: 1)
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
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
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testEnvelopeOptionsDisabled() {
        options.enabled = false
        sendEnvelope(callsCompletionHandler: false)
        
        assertRequestsSent(requestCount: 0)
    }
    
    private func givenRetryAfterResponse() -> HTTPURLResponse {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        requestManager.returnResponse(response: response)
        return response
    }
    
    @discardableResult private func givenRateLimitResponse(forType type: String) -> HTTPURLResponse {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(type):key")
        requestManager.returnResponse(response: response)
        return response
    }
    
    private func givenNoInternetConnection() {
        requestManager.returnResponse(response: nil)
    }
    
    private func givenOkResponse() {
        requestManager.returnResponse(response: HTTPURLResponse.init())
    }
    
    func givenFirstRateLimitGetsActiveWithSecondResponse() {
        var i = -1
        requestManager.returnResponse { () -> HTTPURLResponse? in
            i += 1
            if (i == 0) {
                return HTTPURLResponse.init()
            } else {
                return TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeEvent):key")
            }
        }
    }
    
    private func sendEvent(callsCompletionHandler: Bool = true) {
        var completionHandlerWasCalled = false
        sut.send(event: Event()) { (error) in
            XCTAssertNil(error)
            completionHandlerWasCalled = true
        }
        XCTAssertEqual(callsCompletionHandler, completionHandlerWasCalled)
    }
    
    private func sendEnvelope(envelope: SentryEnvelope = TestConstants.envelope, callsCompletionHandler: Bool = true) {
        var completionHandlerWasCalled = false
        sut.send(envelope: envelope) { (error) in
            XCTAssertNil(error)
            completionHandlerWasCalled = true
        }
        XCTAssertEqual(callsCompletionHandler, completionHandlerWasCalled)
    }
    
    private func assertRateLimitUpdated(response: HTTPURLResponse) {
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertTrue(rateLimits.isRateLimitActive(SentryEnvelopeItemTypeSession))
    }
    
    private func assertRequestsSent(requestCount: Int) {
        XCTAssertEqual(requestCount, requestManager.requests.count)
        assertEventsStored(eventCount: 0)
    }
    
    private func assertEventsStored(eventCount: Int) {
        XCTAssertEqual(eventCount, fileManager.getAllStoredEventsAndEnvelopes().count)
    }
}
