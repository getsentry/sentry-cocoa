import _SentryPrivate
import Nimble
import Sentry
import SentryTestUtils
import XCTest

final class SentrySpotlightTransportTests: XCTestCase {
    
    private var options: Options!
    private var requestManager: TestRequestManager!
    private var requestBuilder: TestNSURLRequestBuilder!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.enableSpotlight = true
        
        requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
        
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
        
        expect(self.requestManager.requests.count) == 1
        
        let request = try XCTUnwrap(requestManager.requests.first)
        expect(request.url?.absoluteString) == options.spotlightUrl
        
        let expectedData = try getSerializedGzippedData(envelope: eventEnvelope)
        expect(request.httpBody) == expectedData
    }
    
    func testShouldSendTransactionEnvelope() throws {
        let transactionEnvelope = try givenTransactionEnvelope()
        let sut = givenSut()
        
        sut.send(envelope: transactionEnvelope)
        
        expect(self.requestManager.requests.count) == 1
        
        let request = try XCTUnwrap(requestManager.requests.first)
        expect(request.url?.absoluteString) == options.spotlightUrl
        
        let expectedData = try getSerializedGzippedData(envelope: transactionEnvelope)
        expect(request.httpBody) == expectedData
    }
    
    func testShouldRemoveAttachmentsFromEventEnvelope() throws {
        let eventEnvelope = try givenEventEnvelope(withAttachment: true)
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        expect(self.requestManager.requests.count) == 1
        
        let request = try XCTUnwrap(requestManager.requests.first)
        expect(request.url?.absoluteString) == options.spotlightUrl
        
        let expectedData = try getSerializedGzippedData(envelope: givenEventEnvelope())
        let expectedDataCountLower = expectedData.count - 20
        let expectedDataCountUpper = expectedData.count + 20
        
        // Compressing with GZip doesn't always produce the same results
        // We only want to know if the attachment got removed. Therefore, a comparison with a range is acceptable.
        expect(request.httpBody?.count).to(beWithin(expectedDataCountLower...expectedDataCountUpper))
    }
    
    func testShouldNotSendEnvelope_WhenMalformedURL() throws {
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailWithError = true
        let sut = givenSut(spotlightUrl: TestData.malformedURLString)
        
        sut.send(envelope: eventEnvelope)
        
        requestManager.waitForAllRequests()
        expect(self.requestManager.requests.count) == 0
    }
    
    func testShouldNotSendEnvelope_WhenRequestError() throws {
        let eventEnvelope = try givenEventEnvelope()
        requestBuilder.shouldFailWithError = true
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        requestManager.waitForAllRequests()
        expect(self.requestManager.requests.count) == 0
    }
    
    func testShouldLogError_WhenRequestManagerCompletesWithError() throws {
        let logOutput = TestLogOutput()
        SentryLog.setLogOutput(logOutput)
        SentryLog.configure(true, diagnosticLevel: .debug)
        
        let eventEnvelope = try givenEventEnvelope()
        requestManager.nextError = NSError(domain: "error", code: 47)
        let sut = givenSut()
        
        sut.send(envelope: eventEnvelope)
        
        requestManager.waitForAllRequests()
        
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [error]") &&
            $0.contains("Error while performing request")
        }
        
        expect(logMessages.count) == 1
    }
    
    private func getSerializedGzippedData(envelope: SentryEnvelope) throws -> Data {
        let expectedData = try SentrySerialization.data(with: envelope) as NSData
        return try expectedData.sentry_gzipped(withCompressionLevel: -1)
    }

}
