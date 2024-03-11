import _SentryPrivate
import Nimble
import Sentry
import SentryTestUtils
import XCTest

class SentryTransportAdapterTests: XCTestCase {
    
    private class Fixture {

        let transport1 = TestTransport()
        let transport2 = TestTransport()
        let options = Options()
        let faultyAttachment = Attachment(path: "")
        let attachment = Attachment(data: Data(), filename: "test.txt")
        
        var sut: SentryTransportAdapter {
            return SentryTransportAdapter(transports: [transport1, transport2], options: options)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryTransportAdapter!

    override func setUp() {
        super.setUp()
        
        SentryDependencyContainer.sharedInstance().dateProvider = TestCurrentDateProvider()
        
        fixture = Fixture()
        sut = fixture.sut
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testSendEventWithSession_SendsCorrectEnvelope() throws {
        let session = SentrySession(releaseName: "1.0.1", distinctId: "some-id")
        let event = TestData.event
        sut.send(event, session: session, attachments: [fixture.attachment])
        
        let expectedEnvelope = SentryEnvelope(id: event.eventId, items: [
            SentryEnvelopeItem(event: event),
            SentryEnvelopeItem(attachment: fixture.attachment, maxAttachmentSize: fixture.options.maxAttachmentSize)!,
            SentryEnvelopeItem(session: session)
        ])
        
        try assertEnvelope(expected: expectedEnvelope)
    }

    func testSendFaultyAttachment_FaultyAttachmentGetsDropped() throws {
        let event = TestData.event
        sut.send(event: event, traceContext: nil, attachments: [fixture.faultyAttachment, fixture.attachment])
        
        let expectedEnvelope = SentryEnvelope(id: event.eventId, items: [
            SentryEnvelopeItem(event: event),
            SentryEnvelopeItem(attachment: fixture.attachment, maxAttachmentSize: fixture.options.maxAttachmentSize)!
        ])
        
        try assertEnvelope(expected: expectedEnvelope)
    }
    
    func testSendUserFeedback_SendsUserFeedbackEnvelope() throws {
        let userFeedback = TestData.userFeedback
        sut.send(userFeedback: userFeedback)
        
        let expectedEnvelope = SentryEnvelope(userFeedback: userFeedback)
        
        try assertEnvelope(expected: expectedEnvelope)
    }
    
    private func assertEnvelope(expected: SentryEnvelope) throws {
        expect(self.fixture.transport1.sentEnvelopes.count) == 1
        expect(self.fixture.transport2.sentEnvelopes.count) == 1
        
        let actual = fixture.transport1.sentEnvelopes.first!
        expect(actual) != nil
        
        expect(expected.header.eventId) == actual.header.eventId
        expect(expected.header.sdkInfo) == actual.header.sdkInfo
        expect(expected.items.count) == actual.items.count
        
        expected.items.forEach { expectedItem in
            let expectedHeader = expectedItem.header
            let containsHeader = actual.items.contains { _ in
                expectedHeader.type == expectedItem.header.type &&
                expectedHeader.contentType == expectedItem.header.contentType
            }
            
            expect(containsHeader).to(beTrue(), description: "Envelope doesn't contain item with type:\(expectedHeader.type).")

            let containsData = actual.items.contains { actualItem in
                actualItem.data == expectedItem.data
            }
            
            expect(containsData).to(beTrue(), description: "Envelope data with type:\(expectedHeader.type) doesn't match.")
        }
        
        let actualSerialized = try SentrySerialization.data(with: actual)
        expect(try SentrySerialization.data(with: expected)) == actualSerialized
    }
}
