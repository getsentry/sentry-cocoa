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
                sentryRateLimits: rateLimits,
                sentryEnvelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits)
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
        assertEventsAndEnvelopesStored(eventCount: 1)
        
        givenOkResponse()
        _ = SentryHttpTransport(
            options: options,
            sentryFileManager: fileManager,
            sentryRequestManager: requestManager,
            sentryRateLimits: rateLimits,
            sentryEnvelopeRateLimit: EnvelopeRateLimit()
        )
        
        assertEventsAndEnvelopesStored(eventCount: 0)
        assertRequestsSent(requestCount: 2)
    }
    
    func testSendOneEvent()  {
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEventsStored(eventCount: 0)
    }
    
    func testSendEventOptionsDisabled() {
        options.enabled = false
        sendEvent(callsCompletionHandler: false)
        sendEvent(callsCompletionHandler: false)
        
        assertRequestsSent(requestCount: 0)
        assertEventsStored(eventCount: 0)
    }
    
    func testSendEventWhenSessionRateLimitActive() {
        rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key"))
        
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEventsStored(eventCount: 0)
    }
    
    func testSendAllCachedEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        givenRateLimitResponse(forCategory: "someCat")
        sendEnvelope()
        
        XCTAssertEqual(3, requestManager.requests.count)
        assertEventsAndEnvelopesStored(eventCount: 0)
    }
    
    func testSendAllCachedEnvelopes() {
        givenNoInternetConnection()
        let envelope = SentryEnvelope(session: SentrySession())
        sendEnvelope(envelope: envelope)
        sendEnvelope()
        
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(5, requestManager.requests.count)
        assertEventsAndEnvelopesStored(eventCount: 0)
    }
    
    func testSendCachedButNotReady() {
        givenNoInternetConnection()
        sendEnvelope()
        
        requestManager.isReady = false
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        assertEventsAndEnvelopesStored(eventCount: 1)
    }
    
    func testSendCachedEventsButRateLimitIsActive() {
        givenNoInternetConnection()
        sendEvent()
        
        // Rate limit changes between sending the event succesfully
        // and calling sending all events. This can happen when for
        // example when multiple requests run in parallel.
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        
        XCTAssertEqual(2, requestManager.requests.count)
        assertEventsAndEnvelopesStored(eventCount: 0)
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
        assertEventsAndEnvelopesStored(eventCount: 0)
    }
    
    func testSendAllEventsAllEventsDeletedWhenNotReady() {
        givenNoInternetConnection()
        sendEvent()
        sendEvent()
        assertEventsAndEnvelopesStored(eventCount: 2)
        
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        assertEventsAndEnvelopesStored(eventCount: 0)
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
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)

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
    
    func testActiveRateLimitForAllEnvelopeItems() {
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        
        sendEnvelope(callsCompletionHandler: false)
        
        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLimitForSomeEnvelopeItems() {
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        
        sendEnvelopeWithSession()
        
        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLImitForAllCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEnvelope()
        
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
        assertEventsAndEnvelopesStored(eventCount: 0)
    }
    
    func testActiveRateLImitForSomeCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEnvelope()
        sendEnvelopeWithSession()
        
        givenRateLimitResponse(forCategory: SentryRateLimitCategoryError)
        sendEvent()
        
        assertRequestsSent(requestCount: 4)
        assertEventsAndEnvelopesStored(eventCount: 0)
    }
    
    func testAllCachedEnvelopesCantDeserializeEnvelope() throws {
        let path = fileManager.store(TestConstants.envelope)
        let faultyEnvelope = Data([0x70, 0xa3, 0x10, 0x45])
        try faultyEnvelope.write(to: URL.init(fileURLWithPath: path))
        
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    /**
     In a previous version of the SentryFileManager events and envelopes
     were stored in the same folder. Therefore it can happen that getAllEventsAndMaybeEnvelopes
     returns envelopes. This test handles this edge case.
     */
    func testEnvelopesStoredInEvents() throws {
        // Write Envelope to events path
        let eventPath = fileManager.store(Event())
        let envelopePath = fileManager.store(TestConstants.envelope)
        let envelopeAsData = FileManager.default.contents(atPath: envelopePath)
        fileManager.deleteAllStoredEventsAndEnvelopes()
        try envelopeAsData?.write(to: URL.init(fileURLWithPath: eventPath))
     
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
        assertEventsAndEnvelopesStored(eventCount: 0)
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
        requestManager.returnResponse(response: HTTPURLResponse.init())
    }
    
    func givenFirstRateLimitGetsActiveWithSecondResponse() {
        var i = -1
        requestManager.returnResponse { () -> HTTPURLResponse? in
            i += 1
            if (i == 0) {
                return HTTPURLResponse.init()
            } else {
                return TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryRateLimitCategoryError):key")
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
    
    private func sendEnvelopeWithSession() {
        let envelope = SentryEnvelope(id: "id", items: [SentryEnvelopeItem(event: Event()), SentryEnvelopeItem(session: SentrySession())])
        sut.send(envelope: envelope, completion: nil)
    }
    
    private func assertRateLimitUpdated(response: HTTPURLResponse) {
        XCTAssertEqual(1, requestManager.requests.count)
        XCTAssertTrue(rateLimits.isRateLimitActive(SentryEnvelopeItemTypeSession))
    }
    
    private func assertRequestsSent(requestCount: Int) {
        XCTAssertEqual(requestCount, requestManager.requests.count)
    }
    
    private func assertEventsAndEnvelopesStored(eventCount: Int) {
        XCTAssertEqual(eventCount, fileManager.getAllStoredEventsAndEnvelopes().count)
    }
    
    private func assertEventsStored(eventCount: Int) {
        XCTAssertEqual(eventCount, fileManager.getAllEventsAndMaybeEnvelopes().count)
    }
    
    private func assertEnvelopesStored(envelopeCount: Int) {
        XCTAssertEqual(envelopeCount, fileManager.getAllEnvelopes().count)
    }
}
