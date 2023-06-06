import Sentry
import SentryTestUtils
import XCTest

class SentryHttpTransportTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryHttpTransportTests")

    private class Fixture {
        let event: Event
        let eventEnvelope: SentryEnvelope
        let eventRequest: SentryNSURLRequest
        let attachmentEnvelopeItem: SentryEnvelopeItem
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
        let requestBuilder = TestNSURLRequestBuilder()
        let rateLimits: DefaultRateLimits
        let dispatchQueueWrapper: TestSentryDispatchQueueWrapper = {
            let dqw = TestSentryDispatchQueueWrapper()
            dqw.dispatchAfterExecutesBlock = true
            return dqw
        }()
        let reachability = TestSentryReachability()
        let flushTimeout: TimeInterval = 0.5

        let userFeedback: UserFeedback
        let userFeedbackRequest: SentryNSURLRequest
        
        let clientReport: SentryClientReport
        let clientReportEnvelope: SentryEnvelope
        let clientReportRequest: SentryNSURLRequest
        
        let queue = DispatchQueue(label: "SentryHttpTransportTests", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])

        init() {
            currentDateProvider = TestCurrentDateProvider()
            CurrentDate.setCurrentDateProvider(currentDateProvider)

            event = Event()
            event.message = SentryMessage(formatted: "Some message")

            eventRequest = buildRequest(SentryEnvelope(event: event))
            
            attachmentEnvelopeItem = SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024)!

            eventEnvelope = SentryEnvelope(id: event.eventId, items: [SentryEnvelopeItem(event: event), attachmentEnvelopeItem])
            // We are comparing byte data and the `sentAt` header is also set in the transport, so we also need them here in the expected envelope.
            eventEnvelope.header.sentAt = CurrentDate.date()
            eventWithAttachmentRequest = buildRequest(eventEnvelope)

            session = SentrySession(releaseName: "2.0.1")
            sessionEnvelope = SentryEnvelope(id: nil, singleItem: SentryEnvelopeItem(session: session))
            sessionEnvelope.header.sentAt = CurrentDate.date()
            sessionRequest = buildRequest(sessionEnvelope)

            let items = [SentryEnvelopeItem(event: event), SentryEnvelopeItem(session: session)]
            eventWithSessionEnvelope = SentryEnvelope(id: event.eventId, items: items)
            eventWithSessionEnvelope.header.sentAt = CurrentDate.date()
            eventWithSessionRequest = buildRequest(eventWithSessionEnvelope)

            options = Options()
            options.dsn = SentryHttpTransportTests.dsnAsString
            fileManager = try! TestFileManager(options: options, andCurrentDateProvider: currentDateProvider)

            requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
            rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())

            userFeedback = TestData.userFeedback
            let userFeedbackEnvelope = SentryEnvelope(userFeedback: userFeedback)
            userFeedbackEnvelope.header.sentAt = CurrentDate.date()
            userFeedbackRequest = buildRequest(userFeedbackEnvelope)
            
            let beforeSendTransaction = SentryDiscardedEvent(reason: .beforeSend, category: .transaction, quantity: 2)
            let sampleRateTransaction = SentryDiscardedEvent(reason: .sampleRate, category: .transaction, quantity: 1)
            let rateLimitBackoffError = SentryDiscardedEvent(reason: .rateLimitBackoff, category: .error, quantity: 1)
            
            clientReport = SentryClientReport(discardedEvents: [
                beforeSendTransaction,
                sampleRateTransaction,
                rateLimitBackoffError
            ])
            
            let clientReportEnvelopeItems = [
                SentryEnvelopeItem(event: event),
                attachmentEnvelopeItem,
                SentryEnvelopeItem(clientReport: clientReport)
            ]
            clientReportEnvelope = SentryEnvelope(id: event.eventId, items: clientReportEnvelopeItems)
            clientReportEnvelope.header.sentAt = CurrentDate.date()
            clientReportRequest = buildRequest(clientReportEnvelope)
        }

        var sut: SentryHttpTransport {
            return SentryHttpTransport(
                options: options,
                fileManager: fileManager,
                requestManager: requestManager,
                requestBuilder: requestBuilder,
                rateLimits: rateLimits,
                envelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits),
                dispatchQueueWrapper: dispatchQueueWrapper,
                reachability: reachability
            ) 
        }
    }

    class func dsn() throws -> SentryDsn {
        try TestConstants.dsn(username: "SentryHttpTransportTests")
    }

    class func buildRequest(_ envelope: SentryEnvelope) -> SentryNSURLRequest {
        let envelopeData = try! SentrySerialization.data(with: envelope)
        return try! SentryNSURLRequest(envelopeRequestWith: dsn(), andData: envelopeData)
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
        fixture.requestManager.waitForAllRequests()
    }

    func testInitSendsCachedEnvelopes() {
        givenNoInternetConnection()
        sendEventAsync()
        assertEnvelopesStored(envelopeCount: 1)

        waitForAllRequests()
        givenOkResponse()
        let sut = fixture.sut
        XCTAssertNotNil(sut)
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
        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()

        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)

        assertEventAndSesionAreSentInOneEnvelope()
    }
    
    func testSendEventWithFaultyNSUrlRequest() {
        let envelope = SentryEnvelope(event: TestConstants.eventWithSerializationError)
        sut.send(envelope: envelope)

        assertRequestsSent(requestCount: 1)
    }
    
    func testSendUserFeedback() {
        let envelope = SentryEnvelope(userFeedback: fixture.userFeedback)
        sut.send(envelope: envelope)
        waitForAllRequests()

        XCTAssertEqual(1, fixture.requestManager.requests.count)

        let actualRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.userFeedbackRequest.httpBody, actualRequest?.httpBody, "Request for user feedback is faulty.")
    }
    
    func testSendEventWithSession_RateLimitForEventIsActive_OnlySessionSent() {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()

        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()

        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)

        // Envelope with only session and client report is sent
        let discardedError = SentryDiscardedEvent(reason: .rateLimitBackoff, category: .error, quantity: 1)
        let clientReport = SentryClientReport(discardedEvents: [discardedError])
        let envelopeItems = [
            SentryEnvelopeItem(session: fixture.session),
            SentryEnvelopeItem(clientReport: clientReport)
        ]
        let envelope = SentryEnvelope(id: fixture.event.eventId, items: envelopeItems)
        envelope.header.sentAt = CurrentDate.date()
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

    func testSendEventWithRetryAfterResponse() {
        fixture.requestManager.nextError = NSError(domain: "something", code: 12)
        
        let response = givenRetryAfterResponse()

        sendEvent()

        assertRateLimitUpdated(response: response)
        assertClientReportNotStoredInMemory()
    }

    func testSendEventWithRateLimitResponse() {
        fixture.requestManager.nextError = NSError(domain: "something", code: 12)

        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypeSession)

        sendEvent()

        assertRateLimitUpdated(response: response)
        assertClientReportStoredInMemory()
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
        let date = fixture.currentDateProvider.date()
        fixture.currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent()

        assertRequestsSent(requestCount: 2)

        // Retry-After expired
        fixture.currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()

        assertRequestsSent(requestCount: 3)
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

        // Make sure that the next calls to sendAllCachedEnvelopes go via
        // dispatchQueue.dispatchAfter, and doesn't just execute it immediately
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAfterInvocations.count, 2)
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAfterInvocations.first?.interval, 0.1)
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
        sessionEnvelope.header.sentAt = CurrentDate.date()
        let sessionData = try! SentrySerialization.data(with: sessionEnvelope)
        let sessionRequest = try! SentryNSURLRequest(envelopeRequestWith: SentryHttpTransportTests.dsn(), andData: sessionData)

        if fixture.requestManager.requests.invocations.count > 3 {
            XCTAssertEqual(sessionRequest.httpBody, fixture.requestManager.requests.invocations[3].httpBody, "Envelope with only session item should be sent.")
        } else {
            XCTFail("Expected a fourth invocation")
        }
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
        XCTAssertEqual(fixture.eventWithAttachmentRequest.httpBody, fixture.requestManager.requests.invocations[1].httpBody, "Cached envelope was not sent first.")

        if fixture.requestManager.requests.invocations.count > 2 {
            XCTAssertEqual(fixture.sessionRequest.httpBody, fixture.requestManager.requests.invocations[2].httpBody, "Cached envelope was not sent first.")
        } else {
            XCTFail("Expected a third invocation")
        }
    }
    
    func testRecordLostEvent_SendingEvent_AttachesClientReport() {
        givenRecordedLostEvents()
        
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.last
        XCTAssertEqual(fixture.clientReportRequest.httpBody, actualEventRequest?.httpBody, "Client report not sent.")
    }
    
    func testRecordLostEvent_SendingEvent_ClearsLostEvents() {
        givenRecordedLostEvents()
        
        sendEvent()
        
        // Second envelope item doesn't contain client reports
        sendEvent()
        assertEventIsSentAsEnvelope()
    }
    
    func testRecordLostEvent_NoInternet_StoredWithEnvelope() {
        givenNoInternetConnection()
        givenRecordedLostEvents()
        
        sendEvent()
        givenOkResponse()
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.first
        XCTAssertEqual(fixture.clientReportRequest.httpBody, actualEventRequest?.httpBody, "Client report not sent.")
    }
    
    func testEventRateLimited_RecordsLostEvent() {
        let rateLimitBackoffError = SentryDiscardedEvent(reason: .rateLimitBackoff, category: .error, quantity: 1)
        let clientReport = SentryClientReport(discardedEvents: [rateLimitBackoffError])
        
        let clientReportEnvelopeItems = [
            fixture.attachmentEnvelopeItem,
            SentryEnvelopeItem(clientReport: clientReport)
        ]
        let clientReportEnvelope = SentryEnvelope(id: fixture.event.eventId, items: clientReportEnvelopeItems)
        clientReportEnvelope.header.sentAt = CurrentDate.date()
        let clientReportRequest = SentryHttpTransportTests.buildRequest(clientReportEnvelope)
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.last
        XCTAssertEqual(clientReportRequest.httpBody, actualEventRequest?.httpBody, "Client report not sent.")
    }
    
    func testCacheFull_RecordsLostEvent() {
        givenNoInternetConnection()
        for _ in 0...fixture.options.maxCacheItems {
            sendEventAsync()
        }
        
        waitForAllRequests()
        
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(2, dict?.count)
        
        let deletedError = dict?["error:cache_overflow"]
        let attachment = dict?["attachment:cache_overflow"]
        XCTAssertEqual(1, deletedError?.quantity)
        XCTAssertEqual(1, attachment?.quantity)
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
            fixture.requestManager.responseDelay = 0.0001

            let queue = fixture.queue

            let group = DispatchGroup()
            for _ in 0...20 {
                group.enter()
                queue.async {
                    self.givenRecordedLostEvents()
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
    
    func testBuildingRequestFails_DeletesEnvelopeAndSendsNext() {
        givenNoInternetConnection()
        sendEvent()
        
        fixture.requestBuilder.shouldFailWithError = true
        sendEvent()
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 1)
    }
    
    func testDeallocated_CachedEnvelopesNotAllSent() throws {
        givenNoInternetConnection()
        givenCachedEvents(amount: 10)
    
        givenOkResponse()
        fixture.dispatchQueueWrapper.dispatchAfterExecutesBlock = false
        
        // Interact with sut in extra function so ARC deallocates it
        func getSut() {
            let sut = fixture.sut
            sut.send(envelope: fixture.eventEnvelope)
            waitForAllRequests()
        }
        getSut()
        
        for dispatchAfterBlock in fixture.dispatchQueueWrapper.dispatchAfterInvocations.invocations {
            dispatchAfterBlock.block()
        }
        
        // The amount of sent envelopes is non deterministic as it depends on how fast ARC deallocates the sut above.
        // We only want to ensure that not all envelopes are sent, so 7 should be fine.
        XCTAssertLessThan(7, fixture.fileManager.getAllEnvelopes().count)
    }
    
    func testBuildingRequestFailsAndRateLimitActive_RecordsLostEvents() {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        
        fixture.requestBuilder.shouldFailWithError = true
        sendEvent()
        
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(1, dict?.count)
        
        let attachment = dict?["attachment:network_error"]
        XCTAssertEqual(1, attachment?.quantity)
        
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 1)
    }
    
    func testBuildingRequestFails_ClientReportNotRecordedAsLostEvent() {
        fixture.requestBuilder.shouldFailWithError = true
        sendEvent()
        sendEvent()
        
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(2, dict?.count)
        
        let event = dict?["error:network_error"]
        let attachment = dict?["attachment:network_error"]
        XCTAssertEqual(1, event?.quantity)
        XCTAssertEqual(1, attachment?.quantity)
        
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 0)
    }
    
    func testRequestManagerReturnsError_RecordsLostEvent() {
        givenErrorResponse()
        
        sendEvent()
        
        assertClientReportStoredInMemory()
    }
    
    func testRequestManagerReturnsError_ClientReportNotRecordedAsLostEvent() {
        givenErrorResponse()
        sendEvent()
        sendEvent()
        
        assertClientReportStoredInMemory()
    }
    
    func testSendClientReportsDisabled_DoesNotRecordLostEvents() {
        fixture.options.sendClientReports = false
        givenErrorResponse()
        
        sendEvent()
        
        assertClientReportNotStoredInMemory()
    }
    
    func testSendClientReportsDisabled_DoesSendClientReport() {
        givenErrorResponse()
        sendEvent()
        
        givenOkResponse()
        fixture.options.sendClientReports = false
        sendEvent()
        
        assertEventIsSentAsEnvelope()
    }
    
    func testFlush_BlocksCallingThread_TimesOut() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        givenCachedEvents(amount: 30)
        
        fixture.requestManager.responseDelay = fixture.flushTimeout + 0.2
        
        let beforeFlush = getAbsoluteTime()
        let result = sut.flush(fixture.flushTimeout)
        let blockingDuration = getDurationNs(beforeFlush, getAbsoluteTime()).toTimeInterval()
        
        XCTAssertGreaterThan(blockingDuration, fixture.flushTimeout)
        XCTAssertLessThan(blockingDuration, fixture.flushTimeout + 0.1)
        
        XCTAssertEqual(.timedOut, result)
    }
    
    func testFlush_BlocksCallingThread_FinishesFlushingWhenSent() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        givenCachedEvents(amount: 1)
        
        let beforeFlush = getAbsoluteTime()
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        let blockingDuration = getDurationNs(beforeFlush, getAbsoluteTime()).toTimeInterval()
        XCTAssertLessThan(blockingDuration, fixture.flushTimeout)
    }
    
    func testFlush_CalledSequentially_BlocksTwice() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        givenCachedEvents()
        
        let beforeFlush = getAbsoluteTime()
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        let blockingDuration = getDurationNs(beforeFlush, getAbsoluteTime()).toTimeInterval()
        
        XCTAssertLessThan(blockingDuration, fixture.flushTimeout * 2.2,
                          "The blocking duration must not exceed the sum of the maximum flush duration.")
    }
    
    func testFlush_WhenNoEnvelopes_BlocksAndFinishes() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        assertFlushBlocksAndFinishesSuccessfully()
    }
    
    func testFlush_WhenNoInternet_BlocksAndFinishes() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        givenCachedEvents()
        givenNoInternetConnection()
        
        assertFlushBlocksAndFinishesSuccessfully()
    }
    
    func testFlush_CalledMultipleTimes_ImmediatelyReturnsFalse() {
        // To avoid spamming the test logs
        SentryLog.configure(true, diagnosticLevel: .error)
        
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider.sharedInstance())
        
        givenCachedEvents(amount: 30)
        
        let flushTimeout = 0.1
        fixture.requestManager.waitForResponseDispatchGroup = true
        fixture.requestManager.responseDispatchGroup.enter()
        
        let allFlushCallsGroup = DispatchGroup()
        let ensureFlushingGroup = DispatchGroup()
        let ensureFlushingQueue = DispatchQueue(label: "First flushing")
        
        sut.setStartFlushCallback {
            ensureFlushingGroup.leave()
        }
        
        allFlushCallsGroup.enter()
        ensureFlushingGroup.enter()
        ensureFlushingQueue.async {
            XCTAssertEqual(.timedOut, self.sut.flush(flushTimeout))
            self.fixture.requestManager.responseDispatchGroup.leave()
            allFlushCallsGroup.leave()
        }
        
        // Ensure transport is flushing.
        ensureFlushingGroup.waitWithTimeout()
        
        // Now the transport should also have left the synchronized block, and the
        // double-checked lock, should return immediately.
        
        let initiallyInactiveQueue = fixture.queue
        for _ in 0..<2 {
            allFlushCallsGroup.enter()
            initiallyInactiveQueue.async {
                for _ in 0..<10 {
                    XCTAssertEqual(.alreadyFlushing, self.sut.flush(flushTimeout), "Double checked lock should have returned immediately")
                }

                allFlushCallsGroup.leave()
            }
        }

        initiallyInactiveQueue.activate()
        allFlushCallsGroup.waitWithTimeout()
        
        setTestDefaultLogLevel()
    }

    func testSendsWhenNetworkComesBack() {
        givenNoInternetConnection()

        sendEvent()

        XCTAssertEqual(1, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 1)

        givenOkResponse()
        fixture.reachability.triggerNetworkReachable()

        XCTAssertEqual(2, fixture.requestManager.requests.count)
    }
    
    func testDealloc_StopsReachabilityMonitoring() {
        _ = fixture.sut

        XCTAssertEqual(1, fixture.reachability.stopMonitoringInvocations.count)
    }
    
    func testDealloc_TriggerNetworkReachable_NoCrash() {
        _ = fixture.sut
        
        fixture.reachability.triggerNetworkReachable()
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
    
    private func givenCachedEvents(amount: Int = 2) {
        givenNoInternetConnection()
        
        for _ in 0..<amount {
            sendEvent()
        }
        
        givenOkResponse()
    }
    
    private func givenErrorResponse() {
        fixture.requestManager.returnResponse(response: HTTPURLResponse())
        fixture.requestManager.nextError = NSError(domain: "something", code: 12)
    }
    
    private func givenRecordedLostEvents() {
        fixture.clientReport.discardedEvents.forEach { event in
            for _ in 0..<event.quantity {
                sut.recordLostEvent(event.category, reason: event.reason)
            }
        }
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
        sut.send(envelope: fixture.eventEnvelope)
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
        XCTAssertTrue(fixture.rateLimits.isRateLimitActive(SentryDataCategory.session))
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
    
    private func assertClientReportStoredInMemory() {
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(2, dict?.count)
        let event = dict?["error:network_error"]
        let attachment = dict?["attachment:network_error"]
        XCTAssertEqual(1, event?.quantity)
        XCTAssertEqual(1, attachment?.quantity)
    }
    
    private func assertClientReportNotStoredInMemory() {
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(0, dict?.count)
    }
    
    private func assertFlushBlocksAndFinishesSuccessfully() {
        let beforeFlush = getAbsoluteTime()
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        let blockingDuration = getDurationNs(beforeFlush, getAbsoluteTime()).toTimeInterval()
        XCTAssertLessThan(blockingDuration, 0.1)
    }
}
