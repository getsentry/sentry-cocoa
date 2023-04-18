import Sentry
import SentryTestUtils
import XCTest

class SentryTransportAdapterTests: XCTestCase {
    
    private class Fixture {

        let transport = TestTransport()
        let options = Options()
        let faultyAttachment = Attachment(path: "")
        let attachment = Attachment(data: Data(), filename: "test.txt")
        
        var sut: SentryTransportAdapter {
            get {
                return SentryTransportAdapter(transport: transport, options: options)
            }
        }
    }

    private var fixture: Fixture!
    private var sut: SentryTransportAdapter!

    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        sut = fixture.sut
    }
    
    func testSendEventWithSession_SendsCorrectEnvelope() throws {
        let session = SentrySession(releaseName: "1.0.1")
        let event = TestData.event
        sut.send(event, session: session, attachments: [fixture.attachment])
        
        let expectedEnvelope = SentryEnvelope(id: event.eventId, items: [
            SentryEnvelopeItem(event: event),
            SentryEnvelopeItem(attachment: fixture.attachment, maxAttachmentSize: fixture.options.maxAttachmentSize)!,
            SentryEnvelopeItem(session: session)
        ])
        
        assertEnvelope(expected: expectedEnvelope)
    }

    func testSendFaultyAttachment_FaultyAttachmentGetsDropped() {
        let event = TestData.event
        sut.send(event: event, attachments: [fixture.faultyAttachment, fixture.attachment])
        
        let expectedEnvelope = SentryEnvelope(id: event.eventId, items: [
            SentryEnvelopeItem(event: event),
            SentryEnvelopeItem(attachment: fixture.attachment, maxAttachmentSize: fixture.options.maxAttachmentSize)!
        ])
        
        assertEnvelope(expected: expectedEnvelope)
    }
    
    func testSendUserFeedback_SendsUserFeedbackEnvelope() {
        let userFeedback = TestData.userFeedback
        sut.send(userFeedback: userFeedback)
        
        let expectedEnvelope = SentryEnvelope(userFeedback: userFeedback)
        
        assertEnvelope(expected: expectedEnvelope)
    }
    
    private func assertEnvelope(expected: SentryEnvelope) {
        XCTAssertEqual(1, fixture.transport.sentEnvelopes.count)
        let actual = fixture.transport.sentEnvelopes.first!
        XCTAssertNotNil(actual)
        
        XCTAssertEqual(expected.header.eventId, actual.header.eventId)
        XCTAssertEqual(expected.header.sdkInfo, actual.header.sdkInfo)
        XCTAssertEqual(expected.items.count, actual.items.count)
        
        expected.items.forEach { expectedItem in
            let expectedHeader = expectedItem.header
            let containsHeader = actual.items.contains { _ in
                expectedHeader.type == expectedItem.header.type &&
                expectedHeader.contentType == expectedItem.header.contentType
            }
            
            XCTAssertTrue(containsHeader, "Envelope doesn't contain item with type:\(expectedHeader.type).")

            let containsData = actual.items.contains { actualItem in
                actualItem.data == expectedItem.data
            }
            
            XCTAssertTrue(containsData, "Envelope data with type:\(expectedHeader.type) doesn't match.")
        }
        
        XCTAssertEqual(try SentrySerialization.data(with: expected), try SentrySerialization.data(with: actual))
    }
}
