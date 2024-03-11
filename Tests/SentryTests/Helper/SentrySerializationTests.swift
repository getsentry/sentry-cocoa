import _SentryPrivate
import XCTest

class SentrySerializationTests: XCTestCase {
    
    private class Fixture {
        static var invalidData = "hi".data(using: .utf8)!
        static var traceContext = SentryTraceContext(trace: SentryId(), publicKey: "PUBLIC_KEY", releaseName: "RELEASE_NAME", environment: "TEST", transaction: "transaction", userSegment: "some segment", sampleRate: "0.25", sampled: "true")
    }

    func testSerializationFailsWithInvalidJSONObject() {
        let json: [String: Any] = [
            "valid object": "hi, i'm a valid object",
            "invalid object": NSDate()
        ]
        let data = SentrySerialization.data(withJSONObject: json)
        XCTAssertNil(data)
    }

    func testSentryEnvelopeSerializer_WithSingleEvent() {
        // Arrange
        let event = Event()

        let item = SentryEnvelopeItem(event: event)
        let envelope = SentryEnvelope(id: event.eventId, singleItem: item)
        envelope.header.sentAt = Date(timeIntervalSince1970: 9_001)
        
        // Sanity check
        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("event", envelope.items[0].header.type)

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertEqual(envelope.header.eventId, deserializedEnvelope.header.eventId)
            assertDefaultSdkInfoSet(deserializedEnvelope: deserializedEnvelope)
            XCTAssertEqual(1, deserializedEnvelope.items.count)
            XCTAssertEqual("event", envelope.items[0].header.type)
            XCTAssertEqual(envelope.items[0].header.length, deserializedEnvelope.items[0].header.length)
            XCTAssertEqual(envelope.items[0].data, deserializedEnvelope.items[0].data)
            XCTAssertNil(deserializedEnvelope.header.traceContext)
            XCTAssertEqual(Date(timeIntervalSince1970: 9_001), deserializedEnvelope.header.sentAt)
        }
    }

    func testSentryEnvelopeSerializer_WithManyItems() {
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

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertNil(deserializedEnvelope.header.eventId)
            XCTAssertEqual(itemsCount, deserializedEnvelope.items.count)
            assertDefaultSdkInfoSet(deserializedEnvelope: deserializedEnvelope)

            for j in 0..<itemsCount {
                XCTAssertEqual("\(j)", envelope.items[j].header.type)
                XCTAssertEqual(
                        envelope.items[j].header.length,
                        deserializedEnvelope.items[j].header.length)
                XCTAssertEqual(envelope.items[j].data, deserializedEnvelope.items[j].data)
            }
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

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertEqual(1, deserializedEnvelope.items.count)
            XCTAssertEqual("attachment", deserializedEnvelope.items[0].header.type)
            XCTAssertEqual(0, deserializedEnvelope.items[0].header.length)
            XCTAssertEqual(0, deserializedEnvelope.items[0].data.count)
            assertDefaultSdkInfoSet(deserializedEnvelope: deserializedEnvelope)
        }
    }

    func testSentryEnvelopeSerializer_SdkInfo() {
        let sdkInfo = SentrySdkInfo(name: "sentry.cocoa", andVersion: "5.0.1")
        let envelopeHeader = SentryEnvelopeHeader(id: nil, sdkInfo: sdkInfo, traceContext: nil)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertEqual(sdkInfo, deserializedEnvelope.header.sdkInfo)
        }
    }
    
    func testSentryEnvelopeSerializer_TraceState() {
        let envelopeHeader = SentryEnvelopeHeader(id: nil, traceContext: Fixture.traceContext)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertNotNil(deserializedEnvelope.header.traceContext)
            assertTraceState(firstTrace: Fixture.traceContext, secondTrace: deserializedEnvelope.header.traceContext!)
        }
    }
    
    func testSentryEnvelopeSerializer_TraceStateWithoutUser() {
        let trace = SentryTraceContext(trace: SentryId(), publicKey: "PUBLIC_KEY", releaseName: "RELEASE_NAME", environment: "TEST", transaction: "transaction", userSegment: nil, sampleRate: nil, sampled: nil)
        
        let envelopeHeader = SentryEnvelopeHeader(id: nil, traceContext: trace)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertNotNil(deserializedEnvelope.header.traceContext)
            assertTraceState(firstTrace: trace, secondTrace: deserializedEnvelope.header.traceContext!)
        }
    }
    
    func testSentryEnvelopeSerializer_SdkInfoIsNil() {
        let envelopeHeader = SentryEnvelopeHeader(id: nil, sdkInfo: nil, traceContext: nil)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())

        assertEnvelopeSerialization(envelope: envelope) { deserializedEnvelope in
            XCTAssertNil(deserializedEnvelope.header.sdkInfo)
        }
    }

    func testSentryEnvelopeSerializer_ZeroByteItemReturnsEnvelope() {
        let itemData = "{}\n{\"length\":0,\"type\":\"attachment\"}\n".data(using: .utf8)!
        XCTAssertNotNil(SentrySerialization.envelope(with: itemData))
    }

    func testSentryEnvelopeSerializer_EnvelopeWithHeaderAndItemWithAttachmet() {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"

        let itemData = """
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       \(payloadAsString)
                       """.data(using: .utf8)!

        if let envelope = SentrySerialization.envelope(with: itemData) {
            XCTAssertEqual(eventId, envelope.header.eventId!)

            XCTAssertEqual(1, envelope.items.count)
            let item = envelope.items[0]
            XCTAssertEqual(10, item.header.length)
            XCTAssertEqual("attachment", item.header.type)
            XCTAssertEqual(payloadAsString.data(using: .utf8), item.data)
        } else {
            XCTFail("Failed to deserialize envelope")
        }
    }

    func testSentryEnvelopeSerializer_ItemWithoutTypeReturnsNil() {
        let itemData = "{}\n{\"length\":0}".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }

    func testSentryEnvelopeSerializer_WithoutItemReturnsNil() {
        let itemData = "{}\n".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }

    func testSentryEnvelopeSerializer_WithoutLineBreak() {
        let itemData = "{}".data(using: .utf8)!
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testSerializeSession() throws {
        let dict = SentrySession(releaseName: "1.0.0", distinctId: "some-id").serialize()
        let session = SentrySession(jsonObject: dict)!
        
        let data = SentrySerialization.data(with: session)
        
        XCTAssertNotNil(SentrySerialization.session(with: data!))
    }
    
    func testSerializeSessionWithNoReleaseName() throws {
        var dict = SentrySession(releaseName: "1.0.0", distinctId: "some-id").serialize()
        dict["attrs"] = nil // Remove release name
        let session = SentrySession(jsonObject: dict)!
        
        let data = SentrySerialization.data(with: session)!
        
        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithEmptyReleaseName() throws {
        let dict = SentrySession(releaseName: "", distinctId: "some-id").serialize()
        let session = SentrySession(jsonObject: dict)!
        
        let data = SentrySerialization.data(with: session)!
        
        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithGarbageInDict() throws {
        var dict = SentrySession(releaseName: "", distinctId: "some-id").serialize()
        dict["started"] = "20"
        let data = SentrySerialization.data(withJSONObject: dict)!
        
        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithGarbage() throws {
        guard let data = "started".data(using: .ascii) else {
            XCTFail("Failed to create data"); return
        }
        
        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testLevelFromEventData() {
        let envelopeItem = SentryEnvelopeItem(event: TestData.event)
        
        let level = SentrySerialization.level(from: envelopeItem.data)
        XCTAssertEqual(TestData.event.level, level)
    }
    
    func testLevelFromEventData_WithGarbage() {
        let level = SentrySerialization.level(from: Fixture.invalidData)
        XCTAssertEqual(SentryLevel.error, level)
    }
    
    func testAppStateWithValidData_ReturnsValidAppState() throws {
        let appState = TestData.appState
        let appStateData = SentrySerialization.data(withJSONObject: appState.serialize())!
        
        let actual = SentrySerialization.appState(with: appStateData)
        
        XCTAssertEqual(appState, actual)
    }
    
    func testAppStateWithInvalidData_ReturnsNil() throws {
        let actual = SentrySerialization.appState(with: Fixture.invalidData)
        
        XCTAssertNil(actual)
    }

    func testDictionaryToBaggageEncoded() {
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value"]), "key=value")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value", "key2": "value2"]), "key2=value2,key=value")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value&"]), "key=value%26")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value="]), "key=value%3D")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value "]), "key=value%20")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value%"]), "key=value%25")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value-_"]), "key=value-_")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": "value\n\r"]), "key=value%0A%0D")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": ""]), "key=")
        
        let largeValue = String(repeating: "a", count: 8_188)
        
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["key": largeValue]), "key=\(largeValue)")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["AKey": "something", "BKey": largeValue]), "AKey=something")
        XCTAssertEqual(SentrySerialization.baggageEncodedDictionary(["AKey": "something", "BKey": largeValue, "CKey": "Other Value"]), "AKey=something,CKey=Other%20Value")
    }

    func testBaggageStringToDictionaryDecoded() {
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value"), ["key": "value"])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key2=value2,key=value"), ["key": "value", "key2": "value2"])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value%26"), ["key": "value&"])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value%3D"), ["key": "value="])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value%20"), ["key": "value "])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value%25"), ["key": "value%"])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value-_"), ["key": "value-_"])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key=value%0A%0D"), ["key": "value\n\r"])
        XCTAssertEqual(SentrySerialization.decodeBaggage(""), [:])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key"), [:])
        XCTAssertEqual(SentrySerialization.decodeBaggage("key="), ["key": ""])
    }
    
    private func serializeEnvelope(envelope: SentryEnvelope) -> Data {
        var serializedEnvelope: Data = Data()
        do {
            serializedEnvelope = try SentrySerialization.data(with: envelope)
        } catch {
            XCTFail("Could not serialize envelope.")
        }
        return serializedEnvelope
    }

    private func createItemWithEmptyAttachment() -> SentryEnvelopeItem {
        let itemData = Data()
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(itemData.count))
        return SentryEnvelopeItem(header: itemHeader, data: itemData)
    }

    private func assertEnvelopeSerialization(
            envelope: SentryEnvelope,
            assert: (SentryEnvelope) -> Void
    ) {
        let serializedEnvelope = serializeEnvelope(envelope: envelope)

        if let deserializedEnvelope = SentrySerialization.envelope(with: serializedEnvelope) {
            assert(deserializedEnvelope)
        } else {
            XCTFail("Could not deserialize envelope.")
        }
    }

    private func assertDefaultSdkInfoSet(deserializedEnvelope: SentryEnvelope) {
        let sdkInfo = SentrySdkInfo(name: SentryMeta.sdkName, andVersion: SentryMeta.versionString)
        XCTAssertEqual(sdkInfo, deserializedEnvelope.header.sdkInfo)
    }
    
    func assertTraceState(firstTrace: SentryTraceContext, secondTrace: SentryTraceContext) {
        XCTAssertEqual(firstTrace.traceId, secondTrace.traceId)
        XCTAssertEqual(firstTrace.publicKey, secondTrace.publicKey)
        XCTAssertEqual(firstTrace.releaseName, secondTrace.releaseName)
        XCTAssertEqual(firstTrace.environment, secondTrace.environment)
        XCTAssertEqual(firstTrace.userSegment, secondTrace.userSegment)
        XCTAssertEqual(firstTrace.sampleRate, secondTrace.sampleRate)
    }
}
