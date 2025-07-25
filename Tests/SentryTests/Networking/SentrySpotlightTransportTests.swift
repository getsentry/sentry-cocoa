@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        transaction.type = SentryEnvelopeItemTypeTransaction
        
        return SentryEnvelope(id: transaction.eventId, items: [SentryEnvelopeItem(event: transaction)])
    }

    func testShouldSendEventEnvelope() throws {
        let eventEnvelope = try givenEventEnvelope()
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        XCTAssertEqual(self.requestManager.requests.count, 1)
        
        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)
        
        let expectedData = try getSerializedGzippedData(envelope: eventEnvelope)
        XCTAssertEqual(request.httpBody, expectedData)
    }
    
    func testShouldSendTransactionEnvelope() throws {
        let transactionEnvelope = try givenTransactionEnvelope()
        let sut = givenSut()
        
        sut.send(envelope: transactionEnvelope)
        
        XCTAssertEqual(self.requestManager.requests.count, 1)
        
        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)
        
        let expectedData = try getSerializedGzippedData(envelope: transactionEnvelope)
        XCTAssertEqual(request.httpBody, expectedData)
    }
    
    func testShouldRemoveAttachmentsFromEventEnvelope() throws {
        let eventEnvelope = try givenEventEnvelope(withAttachment: true)
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        XCTAssertEqual(self.requestManager.requests.count, 1)
        
        let request = try XCTUnwrap(requestManager.requests.first)
        XCTAssertEqual(request.url?.absoluteString, options.spotlightUrl)
        
        let expectedData = try getSerializedGzippedData(envelope: givenEventEnvelope())
        let expectedDataCountLower = expectedData.count - 20
        let expectedDataCountUpper = expectedData.count + 20
        
        // Compressing with GZip doesn't always produce the same results
        // We only want to know if the attachment got removed. Therefore, a comparison with a range is acceptable.
        XCTAssert((expectedDataCountLower...expectedDataCountUpper).contains(try XCTUnwrap(request.httpBody?.count)))
    }
    
    func testShouldNotSendEnvelope_WhenMalformedURL() throws {
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailWithError = true
        let sut = givenSut(spotlightUrl: TestData.malformedURLString)
        
        sut.send(envelope: eventEnvelope)

        XCTAssertEqual(self.requestManager.requests.count, 0)
    }
    
    func testShouldNotSendEnvelope_WhenRequestError() throws {
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailWithError = true
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)

        XCTAssertEqual(self.requestManager.requests.count, 0)
    }
    
    func testShouldNotSendEnvelope_WhenRequestNil() throws {
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailReturningNil = true
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)

        XCTAssertEqual(self.requestManager.requests.count, 0)
    }
    
    func testShouldLogError_WhenRequestManagerCompletesWithError() throws {
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        let eventEnvelope = try givenEventEnvelope()
        requestManager.nextError = NSError(domain: "error", code: 47)
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [error]") &&
            $0.contains("Error while performing request")
        }
        
        XCTAssertEqual(logMessages.count, 1)
    }
    
    private func getSerializedGzippedData(envelope: SentryEnvelope) throws -> Data {
        let expectedData = try XCTUnwrap(SentrySerialization.data(with: envelope)) as NSData
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
