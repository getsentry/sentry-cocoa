import XCTest

// Altough we only run this test above the below specified versions, we exped the
// implementation to be thread safe
@available(tvOS 10.0, *)
@available(OSX 10.12, *)
@available(iOS 10.0, *)
class SentryHttpTransportTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryHttpTransportTests")
    private static let dsn = TestConstants.dsn(username: "SentryHttpTransportTests")
    
    private class Fixture {
        let event: Event
        let eventRequest: SentryNSURLRequest
        let eventWithAttachmentRequest: SentryNSURLRequest
        let eventWithSessionEnvelope: SentryEnvelope
        let eventWithSessionRequest: SentryNSURLRequest
        let session: SentrySession
        let sessionEnvelope: SentryEnvelope
        let sessionRequest: SentryNSURLRequest
        let currentDateProvider: TestCurrentDateProvider
        let fileManager: SentryFileManager
        let options: Options
        let requestManager: TestRequestManager
        let rateLimits: DefaultRateLimits
        
        let userFeedback: UserFeedback
        let userFeedbackRequest: SentryNSURLRequest

        init() {
            currentDateProvider = TestCurrentDateProvider()
            CurrentDate.setCurrentDateProvider(currentDateProvider)

            event = Event()
            event.message = SentryMessage(formatted: "Some message")
            
            eventRequest = buildRequest(SentryEnvelope(event: event))
            
            let eventEnvelope = SentryEnvelope(id: event.eventId, items: [SentryEnvelopeItem(event: event), SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024)!])
            eventWithAttachmentRequest = buildRequest(eventEnvelope)

            session = SentrySession(releaseName: "2.0.1")
            sessionEnvelope = SentryEnvelope(id: nil, singleItem: SentryEnvelopeItem(session: session))
            sessionRequest = buildRequest(sessionEnvelope)

            let items = [SentryEnvelopeItem(event: event), SentryEnvelopeItem(session: session)]
            eventWithSessionEnvelope = SentryEnvelope(id: event.eventId, items: items)
            eventWithSessionRequest = buildRequest(eventWithSessionEnvelope)

            options = Options()
            options.dsn = SentryHttpTransportTests.dsnAsString
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDateProvider)

            requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
            rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())
            
            userFeedback = UserFeedback(eventId: SentryId())
            userFeedback.comments = "It doesn't really"
            userFeedback.email = "john@me.com"
            userFeedback.name = "John Me"
            
            userFeedbackRequest = buildRequest(SentryEnvelope(userFeedback: userFeedback))
        }

        var sut: SentryHttpTransport {
            get {
                return SentryHttpTransport(
                    options: options,
                    fileManager: fileManager,
                    requestManager: requestManager,
                    rateLimits: rateLimits,
                    envelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits),
                    dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
                )
            }
        }
    }

    class func buildRequest(_ envelope: SentryEnvelope) -> SentryNSURLRequest {
        let envelopeData = try! SentrySerialization.data(with: envelope)
        return try! SentryNSURLRequest(envelopeRequestWith: SentryHttpTransportTests.dsn, andData: envelopeData)
    }

    private var fixture: Fixture!
    private var sut: SentryHttpTransport!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        fixture.fileManager.deleteAllEnvelopes()
        fixture.requestManager.returnResponse(response: HTTPURLResponse())

        sut = fixture.sut
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllEnvelopes()
    }
    
    func testInitSendsCachedEnvelopes() {
        givenNoInternetConnection()
        sendEventAsync()
        assertEnvelopesStored(envelopeCount: 1)
        
        waitForAllRequests()
        givenOkResponse()
        _ = fixture.sut
        waitForAllRequests()

        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 2)
    }
    
    func testSendOneEvent() throws {
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }

    func testSendEventWhenSessionRateLimitActive() {
        fixture.rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypeSession):key"))
        
        sendEvent()
        
        assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }

    func testSendEventWithSession_SentInOneEnvelope() {
        sut.send(fixture.event, with: fixture.session, attachments: [])
        waitForAllRequests()

        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)

        assertEventAndSesionAreSentInOneEnvelope()
    }

    func testSendEventWithSession_RateLimitForEventIsActive_OnlySessionSent() {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()

        sut.send(fixture.event, with: fixture.session, attachments: [])

        waitForAllRequests()

        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)

        // Envelope with only Session is sent
        let envelope = SentryEnvelope(id: fixture.event.eventId, items: [SentryEnvelopeItem(session: fixture.session)])
        let request = SentryHttpTransportTests.buildRequest(envelope)
        XCTAssertEqual(request.httpBody, fixture.requestManager.requests.last?.httpBody)
    }

    func testSendAllCachedEvents() {
        givenNoInternetConnection()
        sendEvent()
        
        givenRateLimitResponse(forCategory: "someCat")
        sendEnvelope()
        
        XCTAssertEqual(3, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendAllCachedEnvelopes() {
        givenNoInternetConnection()
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.9.0"))
        sendEnvelope(envelope: envelope)
        sendEnvelope()
        
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(5, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendCachedButNotReady() {
        givenNoInternetConnection()
        sendEnvelope()
        
        fixture.requestManager.isReady = false
        givenOkResponse()
        sendEvent()
        
        XCTAssertEqual(1, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 2)
    }
    
    func testSendCachedEventsButRateLimitIsActive() {
        givenNoInternetConnection()
        sendEvent()
        
        // Rate limit changes between sending the event succesfully
        // and calling sending all events. This can happen when for
        // example when multiple requests run in parallel.
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        XCTAssertEqual(3, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testRateLimitGetsActiveWhileSendAllEvents() {
        givenNoInternetConnection()
        sendEvent()
        sendEvent()
        sendEvent()
        
        // 7 envelopes are saved in the FileManager
        // The next envelope is stored as well and now all 4 should be sent.
        // The first stored envelope from the FileManager is sent normally and for the
        // second envelope the response contains a rate limit.
        // Now 2 envelopes are still to be sent, but they get discarded cause of the
        // active rate limit.
        givenFirstRateLimitGetsActiveWithSecondResponse()
        sendEvent()
        
        XCTAssertEqual(5, fixture.requestManager.requests.count)
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
    
    func ignoredTestSendEventWithRetryAfterResponse() {
        let response = givenRetryAfterResponse()
        
        sendEvent()
        
        assertRateLimitUpdated(response: response)
    }
    
    func ignoredTestSendEventWithRateLimitResponse() {
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
    
    func ignoredTestRateLimitForEvent() {
        givenRateLimitResponse(forCategory: "error")

        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        
        // Retry-After almost expired
        let date = fixture.currentDateProvider.date()
        fixture.currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent()
        
        assertRequestsSent(requestCount: 2)
        
        // Retry-After expired
        fixture.currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()
        
        assertRequestsSent(requestCount: 3)
    }
    
    func testSendEventWithFaultyNSUrlRequest() {
        sut.send(event: TestConstants.eventWithSerializationError, attachments: [])
        
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendOneEnvelope() {
        sendEnvelope()
        
        assertRequestsSent(requestCount: 1)
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
    
    func testActiveRateLimitForAllCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEnvelope()
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        assertRequestsSent(requestCount: 3)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testActiveRateLimitForSomeCachedEnvelopeItems() {
        givenNoInternetConnection()
        sendEvent()
        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        assertRequestsSent(requestCount: 5)
        assertEnvelopesStored(envelopeCount: 0)

        let sessionEnvelope = SentryEnvelope(id: fixture.event.eventId, singleItem: SentryEnvelopeItem(session: fixture.session))

        let sessionData = try! SentrySerialization.data(with: sessionEnvelope)
        let sessionRequest = try! SentryNSURLRequest(envelopeRequestWith: SentryHttpTransportTests.dsn, andData: sessionData)

        XCTAssertEqual(sessionRequest.httpBody, fixture.requestManager.requests[3].httpBody, "Envelope with only session item should be sent.")
    }
    
    func testAllCachedEnvelopesCantDeserializeEnvelope() throws {
        let path = fixture.fileManager.store(TestConstants.envelope)
        let faultyEnvelope = Data([0x70, 0xa3, 0x10, 0x45])
        try faultyEnvelope.write(to: URL(fileURLWithPath: path))
        
        sendEvent()
        
        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testSendCachedEnvelopesFirst() throws {
        givenNoInternetConnection()
        sendEvent()
        
        givenOkResponse()
        sendEnvelopeWithSession()

        fixture.requestManager.waitForAllRequests()
        XCTAssertEqual(3, fixture.requestManager.requests.count)
        XCTAssertEqual(fixture.eventWithAttachmentRequest.httpBody, fixture.requestManager.requests[1].httpBody, "Cached envelope was not sent first.")

        XCTAssertEqual(fixture.sessionRequest.httpBody, fixture.requestManager.requests[2].httpBody, "Cached envelope was not sent first.")
    }

    func testPerformanceOfSending() {
        self.measure {
            givenNoInternetConnection()
            for _ in 0...5 {
                sendEventAsync()
            }
            givenOkResponse()
            for _ in 0...5 {
                sendEventAsync()
            }
        }
    }

    func testSendEnvelopesConcurrent() {
        self.measure {
            fixture.requestManager.responseDelay = 0.000_1

            let queue = DispatchQueue(label: "SentryHubTests", qos: .utility, attributes: [.concurrent, .initiallyInactive])

            let group = DispatchGroup()
            for _ in 0...20 {
                group.enter()
                queue.async {
                    self.sendEventAsync()
                    group.leave()
                }
            }

            queue.activate()
            group.waitWithTimeout()

            waitForAllRequests()
        }

        XCTAssertEqual(210, fixture.requestManager.requests.count)
    }
    
    func testSendUserFeedback() {
        sut.send(userFeedback: fixture.userFeedback)
        waitForAllRequests()
        
        XCTAssertEqual(1, fixture.requestManager.requests.count)
        
        let actualRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.userFeedbackRequest.httpBody, actualRequest?.httpBody, "Request for user feedback is faulty.")
    }
    
    func testSendFaultyAttachment() {
        let faultyAttachment = Attachment(path: "")
        sut.send(event: fixture.event, attachments: [faultyAttachment])
        waitForAllRequests()
        
        XCTAssertEqual(1, fixture.requestManager.requests.count)
        
        // The attachment gets dropped
        let actualRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.eventRequest.httpBody, actualRequest?.httpBody, "Request for faulty attachment is faulty.")
    }

    private func givenRetryAfterResponse() -> HTTPURLResponse {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        fixture.requestManager.returnResponse(response: response)
        return response
    }
    
    @discardableResult private func givenRateLimitResponse(forCategory category: String) -> HTTPURLResponse {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(category):key")
        fixture.requestManager.returnResponse(response: response)
        return response
    }
    
    private func givenNoInternetConnection() {
        fixture.requestManager.returnResponse(response: nil)
    }
    
    private func givenOkResponse() {
        fixture.requestManager.returnResponse(response: HTTPURLResponse())
    }
    
    func givenFirstRateLimitGetsActiveWithSecondResponse() {
        var i = -1
        fixture.requestManager.returnResponse { () -> HTTPURLResponse? in
            i += 1
            if i == 0 {
                return HTTPURLResponse()
            } else {
                return TestResponseFactory.createRateLimitResponse(headerValue: "1::key")
            }
        }
    }
    
    private func waitForAllRequests() {
        fixture.requestManager.waitForAllRequests()
    }

    private func sendEvent() {
        sendEventAsync()
        waitForAllRequests()
    }

    private func sendEventAsync() {
        sut.send(event: fixture.event, attachments: [TestData.dataAttachment])
    }

    private func sendEnvelope(envelope: SentryEnvelope = TestConstants.envelope) {
        sut.send(envelope: envelope)
        waitForAllRequests()
    }
    
    private func sendEnvelopeWithSession() {
        sut.send(envelope: fixture.sessionEnvelope)
        waitForAllRequests()
    }
    
    private func assertRateLimitUpdated(response: HTTPURLResponse) {
        XCTAssertEqual(1, fixture.requestManager.requests.count)
        XCTAssertTrue(fixture.rateLimits.isRateLimitActive(SentryRateLimitCategory.session))
    }
    
    private func assertRequestsSent(requestCount: Int) {
        XCTAssertEqual(requestCount, fixture.requestManager.requests.count)
    }
    
    private func assertEventIsSentAsEnvelope() {
        let actualEventRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.eventWithAttachmentRequest.httpBody, actualEventRequest?.httpBody, "Event was not sent as envelope.")
    }
    
    private func assertEventAndSesionAreSentInOneEnvelope() {
        let actualEventRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.eventWithSessionRequest.httpBody, actualEventRequest?.httpBody, "Request for event with session is faulty.")
    }

    private func assertEnvelopesStored(envelopeCount: Int) {
        XCTAssertEqual(envelopeCount, fixture.fileManager.getAllEnvelopes().count)
    }
}
