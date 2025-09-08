@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable file_length
class SentryHttpTransportTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryHttpTransportTests")

    private class Fixture {
        let event: Event
        let eventEnvelope: SentryEnvelope
        let attachmentEnvelopeItem: SentryEnvelopeItem
        let eventWithAttachmentRequest: URLRequest
        let eventWithSessionEnvelope: SentryEnvelope
        let eventWithSessionRequest: URLRequest
        let session: SentrySession
        let sessionEnvelope: SentryEnvelope
        let sessionRequest: URLRequest
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

#if !os(watchOS)
        let reachability = TestSentryReachability()
#endif // !os(watchOS)

        let flushTimeout: TimeInterval = 2.0
        
        @available(*, deprecated, message: "SentryUserFeedback is deprecated in favor of SentryFeedback.")
        let userFeedback: UserFeedback = TestData.userFeedback
        let feedback: SentryFeedback = TestData.feedback
        @available(*, deprecated, message: "SentryUserFeedback is deprecated in favor of SentryFeedback. There is currently no envelope initializer accepting a SentryFeedback; the envelope is currently built directly in -[SentryClient captureFeedback:withScope:] and sent to -[SentryTransportAdapter sendEvent:traceContext:attachments:additionalEnvelopeItems:].")
        lazy var userFeedbackRequest: URLRequest = {
            let userFeedbackEnvelope = SentryEnvelope(userFeedback: userFeedback)
            userFeedbackEnvelope.header.sentAt = currentDateProvider.date()
            return buildRequest(userFeedbackEnvelope)
        }()
        
        let clientReport: SentryClientReport
        let clientReportEnvelope: SentryEnvelope
        let clientReportRequest: URLRequest
        
        let queue = DispatchQueue(label: "SentryHttpTransportTests", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])

        init() {
            SentryDependencyContainer.sharedInstance().reachability = reachability
            
            currentDateProvider = TestCurrentDateProvider()

            // Event uses the current date provider of the dependency container. Therefore, we need to set it here.
            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider

            event = Event()
            event.message = SentryMessage(formatted: "Some message")
            
            attachmentEnvelopeItem = SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024)!
            
            eventEnvelope = SentryEnvelope(id: event.eventId, items: [SentryEnvelopeItem(event: event), attachmentEnvelopeItem])
            // We are comparing byte data and the `sentAt` header is also set in the transport, so we also need them here in the expected envelope.
            eventEnvelope.header.sentAt = currentDateProvider.date()
            eventWithAttachmentRequest = buildRequest(eventEnvelope)
            
            session = SentrySession(releaseName: "2.0.1", distinctId: "some-id")
            sessionEnvelope = SentryEnvelope(id: nil, singleItem: SentryEnvelopeItem(session: session))
            sessionEnvelope.header.sentAt = currentDateProvider.date()
            sessionRequest = buildRequest(sessionEnvelope)

            let items = [SentryEnvelopeItem(event: event), SentryEnvelopeItem(session: session)]
            eventWithSessionEnvelope = SentryEnvelope(id: event.eventId, items: items)
            eventWithSessionEnvelope.header.sentAt = currentDateProvider.date()
            eventWithSessionRequest = buildRequest(eventWithSessionEnvelope)

            options = Options()
            options.dsn = SentryHttpTransportTests.dsnAsString
            fileManager = try! TestFileManager(options: options)

            requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
            
            let currentDate = TestCurrentDateProvider()
            rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: currentDate), andRateLimitParser: RateLimitParser(currentDateProvider: currentDate), currentDateProvider: currentDate)
            
            let beforeSendTransaction = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.beforeSend), category: nameForSentryDataCategory(.transaction), quantity: 2)
            let sampleRateTransaction = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.sampleRate), category: nameForSentryDataCategory(.transaction), quantity: 1)
            let rateLimitBackoffError = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.rateLimitBackoff), category: nameForSentryDataCategory(.error), quantity: 1)
            
            clientReport = SentryClientReport(discardedEvents: [
                beforeSendTransaction,
                sampleRateTransaction,
                rateLimitBackoffError
            ], dateProvider: SentryDependencyContainer.sharedInstance().dateProvider)
            
            let clientReportEnvelopeItems = [
                SentryEnvelopeItem(event: event),
                attachmentEnvelopeItem,
                SentryEnvelopeItem(clientReport: clientReport)
            ]
            clientReportEnvelope = SentryEnvelope(id: event.eventId, items: clientReportEnvelopeItems)
            clientReportEnvelope.header.sentAt = currentDateProvider.date()
            clientReportRequest = buildRequest(clientReportEnvelope)
        }
        
        func getTransactionEnvelope() -> SentryEnvelope {
            let tracer = SentryTracer(transactionContext: TransactionContext(name: "SomeTransaction", operation: "SomeOperation"), hub: nil)
            
            let child1 = tracer.startChild(operation: "child1")
            let child2 = tracer.startChild(operation: "child2")
            let child3 = tracer.startChild(operation: "child3")
            
            child1.finish()
            child2.finish()
            child3.finish()
            
            tracer.finish()
            
            let transaction = Transaction(
                trace: tracer,
                children: [child1, child2, child3]
            )
            
            let transactionEnvelope = SentryEnvelope(id: transaction.eventId, items: [SentryEnvelopeItem(event: transaction), attachmentEnvelopeItem])
            // We are comparing byte data and the `sentAt` header is also set in the transport, so we also need them here in the expected envelope.
            transactionEnvelope.header.sentAt = currentDateProvider.date()
            
            return transactionEnvelope
        }

        func getSut(
            fileManager: SentryFileManager? = nil,
            dispatchQueueWrapper: SentryDispatchQueueWrapper? = nil
        ) throws -> SentryHttpTransport {
            return SentryHttpTransport(
                dsn: try XCTUnwrap(options.parsedDsn),
                sendClientReports: options.sendClientReports,
                cachedEnvelopeSendDelay: 0.0,
                dateProvider: currentDateProvider,
                fileManager: fileManager ?? self.fileManager,
                requestManager: requestManager,
                requestBuilder: requestBuilder,
                rateLimits: rateLimits,
                envelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits),
                dispatchQueueWrapper: dispatchQueueWrapper ?? self.dispatchQueueWrapper
            )
        }
    }

    private class func dsn() throws -> SentryDsn {
        try TestConstants.dsn(username: "SentryHttpTransportTests")
    }

    private class func buildRequest(_ envelope: SentryEnvelope) -> URLRequest {
        let envelopeData = try! XCTUnwrap(SentrySerialization.data(with: envelope))
        return try! SentryURLRequestFactory.envelopeRequest(with: dsn(), data: envelopeData)
    }

    private var fixture: Fixture!
    private var sut: SentryHttpTransport!

    override func setUpWithError() throws {
        super.setUp()
        fixture = Fixture()
        fixture.fileManager.deleteAllEnvelopes()
        fixture.requestManager.returnResponse(response: HTTPURLResponse())

        sut = try fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllEnvelopes()
        fixture.requestManager.waitForAllRequests()
        clearTestState()
    }

    func testInitSendsCachedEnvelopes() throws {
        givenNoInternetConnection()
        sendEventAsync()
        assertEnvelopesStored(envelopeCount: 1)

        waitForAllRequests()
        givenOkResponse()
        let sut = try fixture.getSut()
        XCTAssertNotNil(sut)
        waitForAllRequests()

        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 2)
    }

    func testSendOneEvent() throws {
        sendEvent()

        assertRequestsSent(requestCount: 1)
        try assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }

    func testSendEventWhenSessionRateLimitActive() throws {
        fixture.rateLimits.update(TestResponseFactory.createRateLimitResponse(headerValue: "1:\(SentryEnvelopeItemTypes.session):key"))

        sendEvent()

        try assertEventIsSentAsEnvelope()
        assertEnvelopesStored(envelopeCount: 0)
    }

    @available(iOS 16.0, *)
    func testSendEventWithSession_SentInOneEnvelope() throws {
        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()

        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)

        try assertEventAndSessionAreSentInOneEnvelope()
    }
    
    func testSendEventWithFaultyNSUrlRequest() {
        let envelope = SentryEnvelope(event: TestConstants.eventWithSerializationError)
        sut.send(envelope: envelope)

        assertRequestsSent(requestCount: 1)
    }
    
    @available(*, deprecated, message: "SentryUserFeedback is deprecated in favor of SentryFeedback. There is currently no envelope initializer accepting a SentryFeedback; the envelope is currently built directly in -[SentryClient captureFeedback:withScope:] and sent to -[SentryTransportAdapter sendEvent:traceContext:attachments:additionalEnvelopeItems:]. This test case can be removed in favor of SentryClientTests.testCaptureFeedback")
    func testSendUserFeedback() throws {
        let envelope = SentryEnvelope(userFeedback: fixture.userFeedback)
        sut.send(envelope: envelope)
        waitForAllRequests()

        XCTAssertEqual(1, fixture.requestManager.requests.count)

        let actualData = try XCTUnwrap(fixture.requestManager.requests.last?.httpBody)
        let expectedData = try XCTUnwrap(fixture.userFeedbackRequest.httpBody)
        let decompressedActualData = try XCTUnwrap(sentry_unzippedData(actualData))
        let decompressedExpectedData = try XCTUnwrap(sentry_unzippedData(expectedData))
        let actualEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: decompressedActualData))
        let expectedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: decompressedExpectedData))
        try EnvelopeUtils.assertEnvelope(expected: expectedEnvelope, actual: actualEnvelope)
    }
    
    func testSendEventWithSession_RateLimitForEventIsActive_OnlySessionSent() throws {
        givenRateLimitResponse(forCategory: "error")
        sendEvent()

        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()

        assertRequestsSent(requestCount: 2)
        assertEnvelopesStored(envelopeCount: 0)

        // Envelope with only session and client report is sent
        let discardedError = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.rateLimitBackoff), category: nameForSentryDataCategory(.error), quantity: 1)
        let clientReport = SentryClientReport(discardedEvents: [discardedError], dateProvider: SentryDependencyContainer.sharedInstance().dateProvider)
        let envelopeItems = [
            SentryEnvelopeItem(session: fixture.session),
            SentryEnvelopeItem(clientReport: clientReport)
        ]
        let envelope = SentryEnvelope(id: fixture.event.eventId, items: envelopeItems)
        envelope.header.sentAt = fixture.currentDateProvider.date()
        let request = SentryHttpTransportTests.buildRequest(envelope)

        let actualData = try XCTUnwrap(request.httpBody)
        let expectedData = try XCTUnwrap(fixture.requestManager.requests.last?.httpBody)
        let decompressedActualData = try XCTUnwrap(sentry_unzippedData(actualData))
        let decompressedExpectedData = try XCTUnwrap(sentry_unzippedData(expectedData))
        let actualEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: decompressedActualData))
        let expectedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: decompressedExpectedData))
        try EnvelopeUtils.assertEnvelope(expected: expectedEnvelope, actual: actualEnvelope)
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
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.9.0", distinctId: "some-id"))
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

        // First rate limit gets active with the second response.
        var i = -1
        fixture.requestManager.returnResponse { () -> HTTPURLResponse? in
            i += 1
            if i == 0 {
                return HTTPURLResponse()
            } else {
                return TestResponseFactory.createRateLimitResponse(headerValue: "1::key")
            }
        }

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

        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypes.session)

        sendEvent()

        assertRateLimitUpdated(response: response)
        assertClientReportStoredInMemory()
    }
    
    func testSendEventWithMetricBucketRateLimitResponse() {
        fixture.requestManager.nextError = NSError(domain: "something", code: 12)

        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypes.session)

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
        let response = givenRateLimitResponse(forCategory: SentryEnvelopeItemTypes.session)

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
        XCTAssertEqual(fixture.dispatchQueueWrapper.dispatchAfterInvocations.first?.interval, 0.0)
    }

    func testActiveRateLimitForSomeCachedEnvelopeItems() throws {
        givenNoInternetConnection()
        sendEvent()
        sut.send(envelope: fixture.eventWithSessionEnvelope)
        waitForAllRequests()

        givenRateLimitResponse(forCategory: "error")
        sendEvent()

        assertRequestsSent(requestCount: 5)
        assertEnvelopesStored(envelopeCount: 0)

        let sessionEnvelope = SentryEnvelope(id: fixture.event.eventId, singleItem: SentryEnvelopeItem(session: fixture.session))
        sessionEnvelope.header.sentAt = fixture.currentDateProvider.date()
        let sessionData = try XCTUnwrap(SentrySerialization.data(with: sessionEnvelope))
        let sessionRequest = try! SentryURLRequestFactory.envelopeRequest(with: SentryHttpTransportTests.dsn(), data: sessionData)

        if fixture.requestManager.requests.invocations.count > 3 {
            let unzippedBody = try XCTUnwrap(sentry_unzippedData(XCTUnwrap(sessionRequest.httpBody)))
            let requestUnzippedBody = try XCTUnwrap(sentry_unzippedData(XCTUnwrap(XCTUnwrap(fixture.requestManager.requests.invocations.element(at: 3)).httpBody)))
            let actualEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: unzippedBody))
            let expectedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: requestUnzippedBody))
            try EnvelopeUtils.assertEnvelope(expected: expectedEnvelope, actual: actualEnvelope)
        } else {
            XCTFail("Expected a fourth invocation")
        }
    }

    func testAllCachedEnvelopesCantDeserializeEnvelope() throws {
        let path = try XCTUnwrap(fixture.fileManager.store(TestConstants.envelope))
        let faultyEnvelope = Data([0x70, 0xa3, 0x10, 0x45])
        try faultyEnvelope.write(to: URL(fileURLWithPath: path))

        sendEvent()

        assertRequestsSent(requestCount: 1)
        assertEnvelopesStored(envelopeCount: 0)
    }
    
    func testFailureToStoreEvenlopeEventStillSendsRequest() throws {
        let fileManger = try TestFileManager(options: fixture.options)
        fileManger.storeEnvelopePathNil = true // Failure to store envelope returns nil path
        let sut = try fixture.getSut(fileManager: fileManger)

        sut.send(envelope: fixture.eventEnvelope)
        
        XCTAssertEqual(fileManger.storeEnvelopeInvocations.count, 1)
        assertRequestsSent(requestCount: 1)
    }

    func testSendCachedEnvelopesFirst() throws {
        givenNoInternetConnection()
        sendEvent()

        givenOkResponse()
        sendEnvelopeWithSession()

        fixture.requestManager.waitForAllRequests()
        XCTAssertEqual(3, fixture.requestManager.requests.count)
        try compareEnvelopes(fixture.eventWithAttachmentRequest.httpBody, try XCTUnwrap(fixture.requestManager.requests.invocations.element(at: 1)).httpBody, message: "Cached envelope was not sent first.")

        if fixture.requestManager.requests.invocations.count > 2 {
            try compareEnvelopes(fixture.sessionRequest.httpBody, try XCTUnwrap(fixture.requestManager.requests.invocations.element(at: 2)).httpBody, message: "Cached envelope was not sent first.")
        } else {
            XCTFail("Expected a third invocation")
        }
    }
    
    func testRecordLostEvent_SendingEvent_AttachesClientReport() throws {
        givenRecordedLostEvents()
        
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.last
        try compareEnvelopes(fixture.clientReportRequest.httpBody, actualEventRequest?.httpBody, message: "Client report not sent.")
    }
    
    func testRecordLostEvent_SendingEvent_ClearsLostEvents() throws {
        givenRecordedLostEvents()
        
        sendEvent()
        
        // Second envelope item doesn't contain client reports
        sendEvent()
        try assertEventIsSentAsEnvelope()
    }
    
    func testRecordLostEvent_NoInternet_StoredWithEnvelope() throws {
        givenNoInternetConnection()
        givenRecordedLostEvents()
        
        sendEvent()
        givenOkResponse()
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.first
        try compareEnvelopes(fixture.clientReportRequest.httpBody, actualEventRequest?.httpBody, message: "Client report not sent.")
    }
    
    func testEventRateLimited_RecordsLostEvent() throws {
        let rateLimitBackoffError = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.rateLimitBackoff), category: nameForSentryDataCategory(.error), quantity: 1)
        let clientReport = SentryClientReport(discardedEvents: [rateLimitBackoffError], dateProvider: SentryDependencyContainer.sharedInstance().dateProvider)
        
        let clientReportEnvelopeItems = [
            fixture.attachmentEnvelopeItem,
            SentryEnvelopeItem(clientReport: clientReport)
        ]
        let clientReportEnvelope = SentryEnvelope(id: fixture.event.eventId, items: clientReportEnvelopeItems)
        clientReportEnvelope.header.sentAt = fixture.currentDateProvider.date()
        let clientReportRequest = SentryHttpTransportTests.buildRequest(clientReportEnvelope)
        
        givenRateLimitResponse(forCategory: "error")
        sendEvent()
        sendEvent()
        
        let actualEventRequest = fixture.requestManager.requests.last
        try compareEnvelopes(clientReportRequest.httpBody, actualEventRequest?.httpBody, message: "Client report not sent.")
    }
    
    func testTransactionRateLimited_RecordsLostSpans() throws {
        let clientReport = SentryClientReport(
            discardedEvents: [
                SentryDiscardedEvent(reason: nameForSentryDiscardReason(.rateLimitBackoff), category: nameForSentryDataCategory(.transaction), quantity: 1),
                SentryDiscardedEvent(reason: nameForSentryDiscardReason(.rateLimitBackoff), category: nameForSentryDataCategory(.span), quantity: 4)
            ],
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider
        )
        
        let clientReportEnvelopeItems = [
            fixture.attachmentEnvelopeItem,
            SentryEnvelopeItem(clientReport: clientReport)
        ]
        
        let transactionEnvelope = fixture.getTransactionEnvelope()
        
        let clientReportEnvelope = SentryEnvelope(id: transactionEnvelope.header.eventId, items: clientReportEnvelopeItems)
        clientReportEnvelope.header.sentAt = fixture.currentDateProvider.date()
        let clientReportRequest = SentryHttpTransportTests.buildRequest(clientReportEnvelope)
        
        givenRateLimitResponse(forCategory: "transaction")
        
        sut.send(envelope: transactionEnvelope)
        waitForAllRequests()
        
        sut.send(envelope: transactionEnvelope)
        waitForAllRequests()
        
        let actualEventRequest = fixture.requestManager.requests.last
        try compareEnvelopes(clientReportRequest.httpBody, actualEventRequest?.httpBody, message: "Client report not sent.")
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
    
    func testCacheFull_RecordsLostSpans() {
        givenNoInternetConnection()
        for _ in 0...fixture.options.maxCacheItems {
            sut.send(envelope: fixture.getTransactionEnvelope())
        }
        
        waitForAllRequests()
        
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(3, dict?.count)
        
        let transaction = dict?["transaction:cache_overflow"]
        let span = dict?["span:cache_overflow"]
        let attachment = dict?["attachment:cache_overflow"]
        XCTAssertEqual(1, transaction?.quantity)
        XCTAssertEqual(4, span?.quantity)
        XCTAssertEqual(1, attachment?.quantity)
    }

    func testSendEnvelopesConcurrent() {
        fixture.requestManager.responseDelay = 0.0001

        let queue = fixture.queue

        let loopCount = 21

        let expectation = XCTestExpectation(description: "Send envelopes concurrently")
        expectation.expectedFulfillmentCount = loopCount

        for _ in 0..<loopCount {
            queue.async {
                self.givenRecordedLostEvents()
                self.sendEventAsync()
                expectation.fulfill()
            }
        }

        queue.activate()
        wait(for: [expectation], timeout: 10)

        waitForAllRequests()

        XCTAssertEqual(self.fixture.requestManager.requests.count, loopCount)
    }
    
    func testBuildingRequestFails_DeletesEnvelopeAndSendsNext() {
        givenNoInternetConnection()
        sendEvent()
        
        fixture.requestBuilder.shouldFailWithError = true
        sendEvent()
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 1)
    }
    
    func testBuildingRequestFailsReturningNil_DeletesEnvelopeAndSendsNext() {
        givenNoInternetConnection()
        sendEvent()
        
        fixture.requestBuilder.shouldFailReturningNil = true
        sendEvent()
        assertEnvelopesStored(envelopeCount: 0)
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendEnvelope_HTTPResponse199_DoesNotDeleteEnvelopeAndStopsSending() throws {
        // Arrange
        let sentryUrl = try XCTUnwrap(URL(string: "https://sentry.io"))
        let response = HTTPURLResponse(url: sentryUrl, statusCode: 199, httpVersion: nil, headerFields: nil)
        
        fixture.requestManager.returnResponse(response: response)
        
        // Act
        sendEvent()
        
        // Assert
        assertEnvelopesStored(envelopeCount: 1)
        assertRequestsSent(requestCount: 1)
    }
    
    func testSendEnvelope_HTTPResponse201_DoesNotDeleteEnvelopeAndStopsSending() throws {
        // Arrange
        let sentryUrl = try XCTUnwrap(URL(string: "https://sentry.io"))
        let response = HTTPURLResponse(url: sentryUrl, statusCode: 201, httpVersion: nil, headerFields: nil)
        
        fixture.requestManager.returnResponse(response: response)
        
        // Act
        sendEvent()
        
        // Assert
        assertEnvelopesStored(envelopeCount: 1)
        assertRequestsSent(requestCount: 1)
    }
    
    func testDeallocated_CachedEnvelopesNotAllSent() throws {
        givenNoInternetConnection()
        givenCachedEvents(amount: 10)
    
        givenOkResponse()
        fixture.dispatchQueueWrapper.dispatchAfterExecutesBlock = false
        
        // Interact with sut in extra function so ARC deallocates it
        func getSut() throws {
            let sut = try fixture.getSut()
            sut.send(envelope: fixture.eventEnvelope)
            waitForAllRequests()
        }
        try getSut()

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
    
    func testBuildingRequestFails_RecordsLostSpans() {
        sendTransaction()
        
        fixture.requestBuilder.shouldFailWithError = true
        sendTransaction()
        
        let dict = Dynamic(sut).discardedEvents.asDictionary as? [String: SentryDiscardedEvent]
        XCTAssertNotNil(dict)
        XCTAssertEqual(3, dict?.count)
        
        let transaction = dict?["transaction:network_error"]
        XCTAssertEqual(1, transaction?.quantity)
        
        let span = dict?["span:network_error"]
        XCTAssertEqual(4, span?.quantity)
        
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
    
    func testSendClientReportsDisabled_DoesNotRecordLostEvents() throws {
        fixture.options.sendClientReports = false
        sut = try fixture.getSut()
        givenErrorResponse()
        
        sendEvent()
        
        assertClientReportNotStoredInMemory()
    }
    
    func testSendClientReportsDisabled_DoesSendClientReport() throws {
        givenErrorResponse()
        sendEvent()
        
        givenOkResponse()
        fixture.options.sendClientReports = false
        sut = try fixture.getSut()
        sendEvent()
        
        try assertEventIsSentAsEnvelope()
    }
    
    func testFlush_BlocksCallingThread_TimesOut() {
        givenCachedEvents(amount: 5)
        fixture.requestManager.responseDelay = fixture.flushTimeout * 2

        let expectation = XCTestExpectation(description: "Flush should time out")
        DispatchQueue.global().async {
            // We don't measure how long the flushing blocks the calling thread, because we can't test this reliably
            // in CI. We did that previously and it led to flakiness.
            // Furthermore, if the flushing blocks a bit longer than the timeout, it is not huge a problem for this test,
            // as it tests if the flushing actually times out.
            let result = self.sut.flush(0.1)

            XCTAssertEqual(.timedOut, result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

    }
    
    func testFlush_BlocksCallingThread_FinishesFlushingWhenSent() {
        givenCachedEvents(amount: 1)

        let beforeFlush = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        let blockingDuration = getDurationNs(beforeFlush, SentryDefaultCurrentDateProvider.getAbsoluteTime()).toTimeInterval()
        XCTAssertLessThan(blockingDuration, fixture.flushTimeout)
    }
    
    func testFlush_CalledSequentially_BlocksTwice() {
        givenCachedEvents()

        let beforeFlush = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        XCTAssertEqual(.success, sut.flush(fixture.flushTimeout), "Flush should not time out.")
        let blockingDuration = getDurationNs(beforeFlush, SentryDefaultCurrentDateProvider.getAbsoluteTime()).toTimeInterval()

        XCTAssertLessThan(blockingDuration, fixture.flushTimeout * 2.2,
                          "The blocking duration must not exceed the sum of the maximum flush duration.")
    }

#if !os(watchOS)
    func testSendsWhenNetworkComesBack() {
        givenNoInternetConnection()

        sendEvent()

        XCTAssertEqual(1, fixture.requestManager.requests.count)
        assertEnvelopesStored(envelopeCount: 1)

        givenOkResponse()
        fixture.reachability.triggerNetworkReachable()

        XCTAssertEqual(2, fixture.requestManager.requests.count)
    }
    
    func testDealloc_StopsReachabilityMonitoring() throws {
        func deallocSut() throws {
            _ = try fixture.getSut()
        }
        try deallocSut()

        XCTAssertEqual(1, fixture.reachability.stopMonitoringInvocations.count)
    }
    
    func testDealloc_TriggerNetworkReachable_NoCrash() throws {
        _ = try fixture.getSut()

        fixture.reachability.triggerNetworkReachable()
    }
#endif // !os(watchOS)
    
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
                sut.recordLostEvent(sentryDataCategoryForString(event.category), reason: sentryDiscardReasonForString(event.reason))
            }
        }
    }

    private func sentryDiscardReasonForString(_ reason: String) -> SentryDiscardReason {
        switch reason {
        case kSentryDiscardReasonNameBeforeSend:
            return .beforeSend
        case kSentryDiscardReasonNameEventProcessor:
            return .eventProcessor
        case kSentryDiscardReasonNameSampleRate:
            return .sampleRate
        case kSentryDiscardReasonNameNetworkError:
            return .networkError
        case kSentryDiscardReasonNameQueueOverflow:
            return .queueOverflow
        case kSentryDiscardReasonNameCacheOverflow:
            return .cacheOverflow
        case kSentryDiscardReasonNameRateLimitBackoff:
            return .rateLimitBackoff
        case kSentryDiscardReasonNameInsufficientData:
            return .insufficientData
        default:
            fatalError("Unsupported reason: \(reason)")
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
    
    private func sendTransaction() {
        sendTransactionAsync()
        waitForAllRequests()
    }
    
    private func sendTransactionAsync() {
        sut.send(envelope: fixture.getTransactionEnvelope())
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

    private func assertEventIsSentAsEnvelope() throws {
        let actualEventRequest = fixture.requestManager.requests.last
        try compareEnvelopes(fixture.eventWithAttachmentRequest.httpBody, actualEventRequest?.httpBody, message: "Event was not sent as envelope.")
    }

    @available(iOS 16.0, *)
    private func assertEventAndSessionAreSentInOneEnvelope() throws {
        let actualEventRequest = fixture.requestManager.requests.last
        try compareEnvelopes(fixture.eventWithSessionRequest.httpBody, actualEventRequest?.httpBody, message: "Request for event with session is faulty.")
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
}
// swiftlint:enable file_length
