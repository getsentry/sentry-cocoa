@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentrySpotlightTransportTests: XCTestCase {
    
    private var options: Options!
    private var requestManager: SyncTestRequestManager!
    private var requestBuilder: TestNSURLRequestBuilder!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.enableSpotlight = true
        
        requestManager = SyncTestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))

        requestBuilder = TestNSURLRequestBuilder()
    }

    override func tearDown() {
        // Reset any log capture set up via `givenCapturedLogs()` so it doesn't leak into other tests.
        SentrySDKLog.setOutput(nil)
        SentrySDKLog.configureLog(false, diagnosticLevel: .error)

        super.tearDown()
    }

    private func givenSut(spotlightUrl: String? = nil) -> SentrySpotlightTransport {
        if spotlightUrl != nil {
            options.spotlightUrl = spotlightUrl ?? ""
        }
        
        return SentrySpotlightTransport(options: options, requestManager: requestManager, requestBuilder: requestBuilder, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }
    
    private func givenEventEnvelope(withAttachment: Bool = false) throws -> SentryEnvelope {
        let event = TestData.event
        
        let attachmentEnvelopeItem = try XCTUnwrap( SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024))
        
        var envelopeItems: [SentryEnvelopeItem]
        if withAttachment {
            envelopeItems = [SentryEnvelopeItem(event: event), attachmentEnvelopeItem]
        } else {
            envelopeItems = [SentryEnvelopeItem(event: event)]
        }
        
        return SentryEnvelope(id: event.eventId, items: envelopeItems)
    }
    
    private func givenTransactionEnvelope() throws -> SentryEnvelope {
        let transaction = Transaction(level: .debug)
        transaction.type = SentryEnvelopeItemTypes.transaction

        return SentryEnvelope(id: transaction.eventId, items: [SentryEnvelopeItem(event: transaction)])
    }

    private func givenTransactionItem() -> SentryEnvelopeItem {
        let transaction = Transaction(level: .debug)
        transaction.type = SentryEnvelopeItemTypes.transaction
        return SentryEnvelopeItem(event: transaction)
    }

    private func givenAttachmentItem() throws -> SentryEnvelopeItem {
        return try XCTUnwrap(SentryEnvelopeItem(attachment: TestData.dataAttachment, maxAttachmentSize: 5 * 1_024 * 1_024))
    }

    /// Captures the SDK logs so tests can assert on them. `tearDown()` restores the default log
    /// configuration so the captured output doesn't leak into other tests.
    ///
    /// Note: we reset in `tearDown()` rather than `addTeardownBlock`, because the latter is only
    /// available on macOS 10.15+ while the test target deploys down to macOS 10.14.
    private func givenCapturedLogs() -> TestLogOutput {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        return logOutput
    }

    func testShouldSendEventEnvelope() throws {
        // -- Arrange --
        let eventEnvelope = try givenEventEnvelope()
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: eventEnvelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)

        let expectedData = try getSerializedGzippedData(envelope: eventEnvelope)
        try compareEnvelopes(request.httpBody, expectedData, message: "Envelopes should be equal")
    }

    func testShouldSendTransactionEnvelope() throws {
        // -- Arrange --
        let transactionEnvelope = try givenTransactionEnvelope()
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: transactionEnvelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)

        let expectedData = try getSerializedGzippedData(envelope: transactionEnvelope)
        try compareEnvelopes(request.httpBody, expectedData, message: "Envelopes should be equal")
    }

    func testShouldRemoveAttachmentsFromEventEnvelope() throws {
        // -- Arrange --
        let eventEnvelope = try givenEventEnvelope(withAttachment: true)
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: eventEnvelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)

        let expectedData = try getSerializedGzippedData(envelope: givenEventEnvelope())
        let expectedDataCountLower = expectedData.count - 40
        let expectedDataCountUpper = expectedData.count + 40

        // Compressing with GZip doesn't always produce the same results
        // We only want to know if the attachment got removed. Therefore, a comparison with a range is acceptable.
        let expectedBodyCountRange = (expectedDataCountLower...expectedDataCountUpper)
        let actualBodyCount = try XCTUnwrap(request.httpBody?.count)
        XCTAssertTrue(expectedBodyCountRange.contains(actualBodyCount), "Expected body size to be in range of \(expectedBodyCountRange), but was \(actualBodyCount)")
    }

    func testShouldKeepEventAndTransaction_AndStripAttachment_WhenEnvelopeHasMixedItems() throws {
        // -- Arrange --
        let eventItem = SentryEnvelopeItem(event: TestData.event)
        let transactionItem = givenTransactionItem()
        let attachmentItem = try givenAttachmentItem()

        // Order matters: the transport preserves the original item order while filtering.
        let envelope = SentryEnvelope(id: TestData.event.eventId, items: [eventItem, attachmentItem, transactionItem])
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: envelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)

        let expectedEnvelope = SentryEnvelope(header: envelope.header, items: [eventItem, transactionItem])
        let expectedData = try getSerializedGzippedData(envelope: expectedEnvelope)
        try compareEnvelopes(request.httpBody, expectedData, message: "Should keep event and transaction and strip the attachment")
    }

    func testShouldKeepAllEventItems_WhenEnvelopeHasMultipleEvents() throws {
        // -- Arrange --
        let firstEventItem = SentryEnvelopeItem(event: TestData.event)
        let secondEventItem = SentryEnvelopeItem(event: TestData.event)

        let envelope = SentryEnvelope(id: TestData.event.eventId, items: [firstEventItem, secondEventItem])
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: envelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        let expectedData = try getSerializedGzippedData(envelope: envelope)
        try compareEnvelopes(request.httpBody, expectedData, message: "Should keep all event items")
    }

    func testShouldSendEnvelopeWithoutItems_WhenNoItemsAreAllowed() throws {
        // -- Arrange --
        let sessionItem = SentryEnvelopeItem(session: SentrySession(releaseName: "release", distinctId: "some-id"))
        let attachmentItem = try givenAttachmentItem()

        let envelope = SentryEnvelope(id: TestData.event.eventId, items: [sessionItem, attachmentItem])
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: envelope)

        // -- Assert --
        // Spotlight strips all non-allowed items but still sends the envelope, now with an empty item list.
        XCTAssertEqual(self.requestManager.requests.count, 1)

        let request = try XCTUnwrap(requestManager.requests.first)
        let expectedEnvelope = SentryEnvelope(header: envelope.header, items: [])
        let expectedData = try getSerializedGzippedData(envelope: expectedEnvelope)
        try compareEnvelopes(request.httpBody, expectedData, message: "Should send an envelope without items when no items are allowed")
    }

    func testShouldNotSendEnvelopeAndLogWarning_WhenMalformedURL() throws {
        // -- Arrange --
        // Guard the test's premise: the transport only takes the malformed-URL path when
        // `NSURL` rejects the string. URL parsing strictness varies by deployment target, so
        // assert up front that the string is actually unparseable on this platform.
        XCTAssertNil(URL(string: TestData.malformedURLString), "Test URL must be unparseable")

        let logOutput = givenCapturedLogs()
        let eventEnvelope = try givenEventEnvelope()
        let sut = givenSut(spotlightUrl: TestData.malformedURLString)

        // -- Act --
        sut.send(envelope: eventEnvelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 0)

        let warnings = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [warning]") &&
            $0.contains("Malformed Spotlight URL")
        }
        XCTAssertEqual(warnings.count, 1)
    }

    func testShouldNotSendEnvelopeAndLogError_WhenRequestBuildFails() throws {
        // -- Arrange --
        let logOutput = givenCapturedLogs()
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailWithError = true
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: eventEnvelope)

        // -- Assert --
        XCTAssertEqual(self.requestManager.requests.count, 0)

        let errors = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [error]") &&
            $0.contains("Unable to build envelope request")
        }
        XCTAssertEqual(errors.count, 1)
    }

    func testShouldLogError_WhenRequestManagerCompletesWithError() throws {
        // -- Arrange --
        let logOutput = givenCapturedLogs()

        let eventEnvelope = try givenEventEnvelope()
        requestManager.nextError = NSError(domain: "error", code: 47)
        let sut = givenSut()

        // -- Act --
        sut.send(envelope: eventEnvelope)

        // -- Assert --
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [error]") &&
            $0.contains("Error while performing request") &&
            // The completion handler must log the actual error, not the (nil) request-build error.
            $0.contains("Code=47")
        }

        XCTAssertEqual(logMessages.count, 1)
    }
    
    private func getSerializedGzippedData(envelope: SentryEnvelope) throws -> Data {
        let expectedData = try XCTUnwrap(SentrySerializationSwift.data(with: envelope)) as NSData
        return try SentryNSDataUtils.sentry_gzipped(with: expectedData as Data, compressionLevel: -1)
    }
}

/// The SentrySpotlightTransport has simple logic and doesn't require the TestRequestManager using dispatch queues to validate its logic.
/// This simplifies the tests by removing DispatchQueues and makes them more deterministic.
private class SyncTestRequestManager: NSObject, RequestManager {

    var nextError: NSError?
    public var isReady: Bool

    var requests = Invocations<URLRequest>()

    public required init(session: URLSession) {
        self.isReady = true
    }

    public func add( _ request: URLRequest, completionHandler: SentryRequestOperationFinished? = nil) {
        requests.record(request)

        if let handler = completionHandler {
            handler(nil, self.nextError)
        }
    }
}
