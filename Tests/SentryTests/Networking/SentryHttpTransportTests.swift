import XCTest

class SentryHttpTransportTests: XCTestCase {
    
    private var fileManager: SentryFileManager!
    private var options: Options!
    private var requestManager: TestRequestManager!
    private var currentDateProvider: TestCurrentDateProvider!
    private var rateLimits: DefaultRateLimits!
    private var event: Event!
    private var sut: SentryHttpTransport!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        event = Event()
        event.message = "Some message"

        do {
            fileManager = try SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
            fileManager.deleteAllEnvelopes()

            requestManager = TestRequestManager(session: URLSession())
            requestManager.returnResponse(response: HTTPURLResponse())
            
            options = try Options(dict: ["dsn": TestConstants.dsnAsString])
            
            rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())
            
            sut = SentryHttpTransport(
                options: options,
                sentryFileManager: fileManager,
                sentryRequestManager: requestManager,
                sentryRateLimits: rateLimits,
                sentryEnvelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits)
            )
        } catch {
            XCTFail("SentryHttpTransport could not be created")
        }
    }
    
    override func tearDown() {
        fileManager.deleteAllEnvelopes()
    }
    
    func testInitSendsCachedEnvelopes() {
        givenNoInternetConnection()
        sendEvent()
        assertEnvelopesStored(envelopeCount: 1)
        
        givenOkResponse()
        _ = SentryHttpTransport(
            options: options,
            sentryFileManager: fileManager,
            sentryRequestManager: requestManager,
            sentryRateLimits: rateLimits,
            sentryEnvelopeRateLimit: EnvelopeRateLimit()
        )
        
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 2)
    }
    
    func testSendOneEvent() throws {
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendEventOptionsDisabled() {
        options.enabled = false
        sendEvent()
        sendEvent()
        
        assertRequestsSent(requestCount: 0)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendEventWhenSessionRateLimitActive() {
        rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key"))
        
        sendEvent()
        
        assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendAllCachedEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        givenRateLimitResponse(forCategory: "someCat")
        sendEnvelope()
        
        XCTAssertEqual(3, requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendAllCachedEnvelopes() {
        givenNoInternetConnection()
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.9.0"))
        sendEnvelope(envelope: envelope)
        sendEnvelope()
        
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(5, requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendCachedButNotReady() {
        givenNoInternetConnection()
        sendEnvelope()
        
        requestManager.isReady = false
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 1)
    }
    
    func testSendCachedEventsButRateLimitIsActive() {
        givenNoInternetConnection()
        sendEvent()
        
        // Rate limit changes between sending the event succesfully
        // and calling sending all events. This can happen when for
        // example when multiple requests run in parallel.
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
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
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendAllEventsAllEventsDeletedWhenNotReady() {
        givenNoInternetConnection()
        sendEvent()
        sendEvent()
        assertEnvelopesStored(envelopeCount: 2)
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendEventWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEventWithRateLimitResponse() {
        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypeSession)
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testSendEnvelopeWithRateLimitResponse() {
        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypeSession)
        
        sendEnvelope()
        
        assertRateLimitUpdated(response: response)
    }
    
    func testRateLimitForEvent() {
        givenRateLimitResponse(forCategory: "error")

        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
    }
    
    func testSendEventWithFaultyNSUrlRequest() {
        sut.send(event: TestConstants.eventWithSerializationError)
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendOneEnvelope() {
        sendEnvelope()
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testEnvelopeOptionsDisabled() {
        options.enabled = false
        sendEnvelope()
        
        assertRequestsSent(requestCount: 0)
    }
    
    func testActiveRateLimitForAllEnvelopeItems() {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        sendEnvelope()
        
        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLimitForSomeEnvelopeItems() {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        sendEnvelopeWithSession()
        
        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLImitForAllCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEnvelope()
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLImitForSomeCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEnvelope()
        sendEnvelopeWithSession()
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        assertRequestsSent(requestCount: 4)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testAllCachedEnvelopesCantDeserializeEnvelope() throws {
        let path = fileManager.store(TestConstants.envelope)
        let faultyEnvelope = Data([0x70, 0xa3, 0x10, 0x45])
        try faultyEnvelope.write(to: URL(fileURLWithPath: path))
        
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }

    private func givenRetryAfterResponse() -> HTTPURLResponse {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        requestManager.returnResponse(response: response)
        return response
    }
    
    @discardableResult private func givenRateLimitResponse(forCategory category: String) -> HTTPURLResponse {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(category):key")
        requestManager.returnResponse(response: response)
        return response
    }
    
    private func givenNoInternetConnection() {
        requestManager.returnResponse(response: nil)
    }
    
    private func givenOkResponse() {
        requestManager.returnResponse(response: HTTPURLResponse())
    }
    
    func givenFirstRateLimitGetsActiveWithSecondResponse() {
        var i = -1
        requestManager.returnResponse { () -> HTTPURLResponse? in
            i += 1
            if i == 0 {
                return HTTPURLResponse()
            } else {
                return TestResponseFactory.createRateLimitResponse(headerValue: "1:error:key")
            }
        }
    }
    
    private func sendEvent() {
        sut.send(event: event)
    }
    
    private func sendEnvelope(envelope: SentryEnvelope = TestConstants.envelope) {
        sut.send(envelope: envelope)
    }
    
    private func sendEnvelopeWithSession() {
        let envelope = SentryEnvelope(id: SentryId(), items: [SentryEnvelopeItem(event: Event()), SentryEnvelopeItem(session: SentrySession(releaseName: "2.0.1"))])
        sut.send(envelope: envelope)
    }
    
    private func assertRateLimitUpdated(response: HTTPURLResponse) {
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertTrue(rateLimits.isRateLimitActive(SentryRateLimitCategory.session))
    }
    
    private func assertRequestsSent(requestCount: Int) {
        XCTAssertEqual(requestCount, requestManager.requests.count)
    }
    
    private func assertEventIsSentAsEnvelope() {
        do {
            let eventData = try SentrySerialization.data(with: SentryEnvelope(event: event))
            let expectedEventRequest = try SentryNSURLRequest(envelopeRequestWith: TestConstants.dsn, andData: eventData)
            let actualEventRequest = requestManager.requests.last
            XCTAssertEqual(expectedEventRequest.httpBody, actualEventRequest?.httpBody, "Event was not sent as envelope.")
        } catch {
            XCTFail("Last event was not send as envelope.")
        }
    }
    
    private func assertEnvelopesStored(envelopeCount: Int) {
        XCTAssertEqual(envelopeCount, fileManager.getAllEnvelopes().count)
    }
}
