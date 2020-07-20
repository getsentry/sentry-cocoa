import XCTest

class SentryEnvelopeTests: XCTestCase {
    
    private let defaultSdkInfo = SentrySdkInfo(name: SentryMeta.sdkName, andVersion: SentryMeta.versionString)
    
    func testSentryEnvelopeFromEvent() {
        let event = Event()
        
        let item = SentryEnvelopeItem(event: event)
        let envelope = SentryEnvelope(id: event.eventId, singleItem: item)
        
        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("event", envelope.items[0].header.type)
        
        let json = try! JSONSerialization.data(withJSONObject: event.serialize(), options: JSONSerialization.WritingOptions(rawValue: 0))
        
        assertJsonIsEqual(actual: json, expected: envelope.items[0].data)
    }
    
    func testSentryEnvelopeWithExplicitInitMessages() {
        let attachment = "{}"
        let data = attachment.data(using: .utf8)!
        
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(data.count))
        let item = SentryEnvelopeItem(header: itemHeader, data: data)
        
        let envelopeId = "hopefully valid envelope id"
        let header = SentryEnvelopeHeader(id: envelopeId)
        let envelope = SentryEnvelope(header: header, singleItem: item)
        
        XCTAssertEqual(envelopeId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("attachment", envelope.items[0].header.type)
        XCTAssertEqual(attachment.count, Int(envelope.items[0].header.length))
        
        XCTAssertEqual(data, envelope.items[0].data)
    }
    
    func testSentryEnvelopeWithExplicitInitMessagesMultipleItems() {
        var items: [SentryEnvelopeItem] = []
        let itemCount = 3
        var attachment = ""
        attachment += UUID().uuidString

        for _ in 0..<itemCount {
            attachment += UUID().uuidString
            let data = attachment.data(using: .utf8)!
            let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(data.count))
            let item = SentryEnvelopeItem(header: itemHeader, data: data)
            items.append(item)
        }

        let envelopeId = "hopefully valid envelope id"
        let envelope = SentryEnvelope(id: envelopeId, items: items)

        XCTAssertEqual(envelopeId, envelope.header.eventId)
        XCTAssertEqual(itemCount, envelope.items.count)

        for i in 0..<itemCount {
            XCTAssertEqual("attachment", envelope.items[i].header.type)
        }
    }
    
    func testInitSentryEnvelopeHeader_DefaultSdkInfoIsSet() {
        XCTAssertEqual(defaultSdkInfo, SentryEnvelopeHeader(id: nil).sdkInfo)
    }
    
    func testInitSentryEnvelopeHeader_IdAndSkInfoNil() {
        let allNil = SentryEnvelopeHeader(id: nil, andSdkInfo: nil)
        XCTAssertNil(allNil.eventId)
        XCTAssertNil(allNil.sdkInfo)
    }
    
    func testInitSentryEnvelopeHeader_SetIdAndSdkInfo() {
        let eventId = "some id"
        let sdkInfo = SentrySdkInfo(name: "sdk", andVersion: "1.2.3-alpha.0")
        
        let envelopeHeader = SentryEnvelopeHeader(id: eventId, andSdkInfo: sdkInfo)
        XCTAssertEqual(eventId, envelopeHeader.eventId)
        XCTAssertEqual(sdkInfo, envelopeHeader.sdkInfo)
    }
    
    func testInitSentryEnvelopeWithSession_DefaultSdkInfoIsSet() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.1.1"))
        
        XCTAssertEqual(defaultSdkInfo, envelope.header.sdkInfo)
    }
}
