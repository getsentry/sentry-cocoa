import XCTest

class SentrySerializationTests: XCTestCase {

    func testSentryEnvelopeSerializesWithSingleEvent() {
        // Arrange
        let event = Event()
        
        let item = SentryEnvelopeItem(event: event)
        let envelope = SentryEnvelope(id: event.eventId, singleItem: item)
        // Sanity check
        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("event", envelope.items[0].header.type)
        
        // Act
        let serializedEnvelope = serializeEnvelope(envelope: envelope)

        // Assert
        if let actual = SentrySerialization.envelope(with: serializedEnvelope) {
            XCTAssertEqual(envelope.header.eventId, actual.header.eventId)
            XCTAssertEqual(1, actual.items.count)
            XCTAssertEqual("event", envelope.items[0].header.type)
            XCTAssertEqual(envelope.items[0].header.length, actual.items[0].header.length)
            XCTAssertEqual(envelope.items[0].data, actual.items[0].data)
        } else {
            XCTFail("Could not deserialize envelope.")
        }
    }

    func testSentryEnvelopeSerializesWithManyItems() {
        // Arrange
        let itemsCount = 15
        var items: [SentryEnvelopeItem] = []
        for i in 0..<itemsCount {
            let bodyChar = "\(i)"
            let bodyString = bodyChar.padding(
                toLength: i + 1,
                withPad: bodyChar,
                startingAt: 0)

            let itemData = bodyString.data(using: .utf8)!
            let itemHeader = SentryEnvelopeItemHeader(type: bodyChar, length: UInt(itemData.count))
            let item = SentryEnvelopeItem(
                header: itemHeader,
                data: itemData)
            items.append(item)
        }

        let envelope = SentryEnvelope(id: nil, items: items)
        // Sanity check
        XCTAssertNil(envelope.header.eventId)
        XCTAssertEqual(itemsCount, Int(envelope.items.count))
        
        // Act
        let serializedEnvelope = serializeEnvelope(envelope: envelope)
        
        // Assert
        if let deserializedEnvelope = SentrySerialization.envelope(with: serializedEnvelope) {
            XCTAssertNil(deserializedEnvelope.header.eventId)
            XCTAssertEqual(itemsCount, deserializedEnvelope.items.count)
            
            for j in 0..<itemsCount {
                XCTAssertEqual("\(j)", envelope.items[j].header.type)
                XCTAssertEqual(
                    envelope.items[j].header.length,
                    deserializedEnvelope.items[j].header.length)
                XCTAssertEqual( envelope.items[j].data, deserializedEnvelope.items[j].data)
            }
        } else {
            XCTFail("Could not deserialize envelope.")
        }
    }
    
    func testSentryEnvelopeSerializesWithZeroByteItem() {
        // Arrange
        let itemData = Data()
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(itemData.count))

        let item = SentryEnvelopeItem(header: itemHeader, data: itemData)
        let envelope = SentryEnvelope(id: nil, singleItem: item)

        // Sanity check
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("attachment", envelope.items[0].header.type)
        XCTAssertEqual(0, Int(envelope.items[0].header.length))
        
        // Act
        let serializedEnvelope = serializeEnvelope(envelope: envelope)
        
        // Assert
        if let deserializedEnvelope = SentrySerialization.envelope(with: serializedEnvelope) {
            XCTAssertEqual(1, deserializedEnvelope.items.count)
            XCTAssertEqual("attachment", deserializedEnvelope.items[0].header.type)
            XCTAssertEqual(0, deserializedEnvelope.items[0].header.length)
            XCTAssertEqual(0, deserializedEnvelope.items[0].data.count)
        } else {
            XCTFail("Could not deserialize envelope.")
        }
    }
    
    func testSentryEnvelopeSerializerZeroByteItemReturnsEnvelope() {
        let itemData = "{}\n{\"length\":0,\"type\":\"attachment\"}\n".data(using: .utf8)!
        XCTAssertNotNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testSentryEnvelopeSerializerItemWithoutTypeReturnsNil() {
        let itemData = "{}\n{\"length\":0}".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testSentryEnvelopeSerializerWithoutItemReturnsNill() {
        let itemData = "{}\n".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testSentryEnvelopeSerializerWithoutLineBreak() {
        let itemData = "{}".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }

    private func serializeEnvelope(envelope: SentryEnvelope) -> Data {
        var serializedEnvelope: Data = Data()
        do {
            serializedEnvelope = try SentrySerialization.data(
                    with: envelope,
                    options: JSONSerialization.WritingOptions(rawValue: 0))
        } catch {
            XCTFail("Could not serialize envelope.")
        }
        return serializedEnvelope
    }
}
