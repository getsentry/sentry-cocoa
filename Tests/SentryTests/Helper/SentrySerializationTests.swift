@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentrySerializationTests: XCTestCase {
    
    private class Fixture {
        static var invalidData = Data("hi".utf8)
        static var traceContext = TraceContext(
            trace: SentryId(),
            publicKey: "PUBLIC_KEY",
            releaseName: "RELEASE_NAME",
            environment: "TEST",
            transaction: "transaction",
            userSegment: "some segment",
            sampleRate: "0.25",
            sampleRand: "0.6543",
            sampled: "true",
            replayId: nil
        )
    }

    override func setUp() {
        super.setUp()
        clearTestState()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testSerializationFailsWithInvalidJSONObject() {
        let json: [String: Any] = [
            "valid object": "hi, i'm a valid object",
            "invalid object": NSDate()
        ]
        let data = SentrySerialization.data(withJSONObject: json)
        XCTAssertNil(data)
    }
    
    func testSerializationFailsWithFirstValidAndThenInvalidJSONObject() {
        let json = [ SentryInvalidJSONString(lengthInvocationsToBeInvalid: 1)]
        let data = SentrySerialization.data(withJSONObject: json)
        XCTAssertNil(data)
    }
    
    func testEnvelopeWithData_InvalidEnvelopeHeaderJSON_ReturnsNil() {
        let sdkInfoWithInvalidJSON = SentrySdkInfo(name: SentryInvalidJSONString() as String, version: "8.0.0", integrations: [], features: [], packages: [])
        let headerWithInvalidJSON = SentryEnvelopeHeader(id: nil, sdkInfo: sdkInfoWithInvalidJSON, traceContext: nil)
        
        let envelope = SentryEnvelope(header: headerWithInvalidJSON, items: [])
        
        XCTAssertNil(SentrySerialization.data(with: envelope))
    }
    
    func testEnvelopeWithData_InvalidEnvelopeItemHeaderJSON_ReturnsNil() throws {
        let envelopeItemHeader = SentryEnvelopeItemHeader(type: SentryInvalidJSONString() as String, length: 0)
        let envelopeItem = SentryEnvelopeItem(header: envelopeItemHeader, data: Data())
        
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: SentryId()), singleItem: envelopeItem)
        
        XCTAssertNil(SentrySerialization.data(with: envelope))
    }
    
    func testEnvelopeWithData_WithSingleEvent() throws {
        // Arrange
        let event = Event()
        
        let item = SentryEnvelopeItem(event: event)
        let envelope = SentryEnvelope(id: event.eventId, singleItem: item)
        envelope.header.sentAt = Date(timeIntervalSince1970: 9_001)
        
        // Sanity check
        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("event", try XCTUnwrap(envelope.items.first).header.type)
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertEqual(envelope.header.eventId, deserializedEnvelope.header.eventId)
        assertDefaultSdkInfoSet(deserializedEnvelope: deserializedEnvelope)
        XCTAssertEqual(1, deserializedEnvelope.items.count)
        XCTAssertEqual("event", try XCTUnwrap(envelope.items.first).header.type)
        XCTAssertEqual(try XCTUnwrap(envelope.items.first).header.length, try XCTUnwrap(deserializedEnvelope.items.first).header.length)
        XCTAssertEqual(try XCTUnwrap(envelope.items.first).data, try XCTUnwrap(deserializedEnvelope.items.first).data)
        XCTAssertNil(deserializedEnvelope.header.traceContext)
        XCTAssertEqual(Date(timeIntervalSince1970: 9_001), deserializedEnvelope.header.sentAt)
    }
    
    func testEnvelopeWithData_WithManyItems() throws {
        // Arrange
        let itemsCount = 15
        var items: [SentryEnvelopeItem] = []
        for i in 0..<itemsCount {
            let bodyChar = "\(i)"
            let bodyString = bodyChar.padding(
                toLength: i + 1,
                withPad: bodyChar,
                startingAt: 0)
            
            let itemData = Data(bodyString.utf8)
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
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
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
    
    func testEnvelopeWithData_EmptyAttachment_ReturnsEnvelope() throws {
        // Arrange
        let itemData = Data()
        let itemHeader = SentryEnvelopeItemHeader(type: "attachment", length: UInt(itemData.count))
        
        let item = SentryEnvelopeItem(header: itemHeader, data: itemData)
        let envelope = SentryEnvelope(id: nil, singleItem: item)
        
        // Sanity check
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("attachment", try XCTUnwrap(envelope.items.first).header.type)
        XCTAssertEqual(0, Int(try XCTUnwrap(envelope.items.first).header.length))
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertEqual(1, deserializedEnvelope.items.count)
        XCTAssertEqual("attachment", try XCTUnwrap(deserializedEnvelope.items.first).header.type)
        XCTAssertEqual(0, try XCTUnwrap(deserializedEnvelope.items.first).header.length)
        XCTAssertEqual(0, try XCTUnwrap(deserializedEnvelope.items.first).data.count)
        assertDefaultSdkInfoSet(deserializedEnvelope: deserializedEnvelope)
    }
    
    func testEnvelopeWithData_WithSdkInfo_ReturnsSDKInfo() throws {
        let sdkInfo = SentrySdkInfo(name: "sentry.cocoa", version: "5.0.1", integrations: [], features: [], packages: [])
        let envelopeHeader = SentryEnvelopeHeader(id: nil, sdkInfo: sdkInfo, traceContext: nil)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertEqual(sdkInfo, deserializedEnvelope.header.sdkInfo)
    }
    
    func testEnvelopeWithData_WithTraceContext_ReturnsTraceContext() throws {
        let envelopeHeader = SentryEnvelopeHeader(id: nil, traceContext: Fixture.traceContext)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertNotNil(deserializedEnvelope.header.traceContext)

        let traceContext = try XCTUnwrap(deserializedEnvelope.header.traceContext)
        assertTraceState(firstTrace: Fixture.traceContext, secondTrace: traceContext)
    }
    
    func testEnvelopeWithData_TraceContextWithoutUser_ReturnsTraceContext() throws {
        let trace = TraceContext(trace: SentryId(), publicKey: "PUBLIC_KEY", releaseName: "RELEASE_NAME", environment: "TEST", transaction: "transaction", userSegment: nil, sampleRate: nil, sampled: nil, replayId: nil)
        
        let envelopeHeader = SentryEnvelopeHeader(id: nil, traceContext: trace)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertNotNil(deserializedEnvelope.header.traceContext)

        let traceContext = try XCTUnwrap(deserializedEnvelope.header.traceContext)
        assertTraceState(firstTrace: trace, secondTrace: traceContext)
    }

    func testEnvelopeWithDataWithSampleRand_TraceContextWithoutUser_ReturnsTraceContext() throws {
        // -- Arrange --
        let trace = TraceContext(
            trace: SentryId(),
            publicKey: "PUBLIC_KEY",
            releaseName: "RELEASE_NAME",
            environment: "TEST",
            transaction: "transaction",
            userSegment: nil,
            sampleRate: nil,
            sampleRand: nil,
            sampled: nil,
            replayId: nil
        )

        // -- Act --
        let envelopeHeader = SentryEnvelopeHeader(id: nil, traceContext: trace)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))

        // -- Assert --
        XCTAssertNotNil(deserializedEnvelope.header.traceContext)
        let traceContext = try XCTUnwrap(deserializedEnvelope.header.traceContext)
        assertTraceState(firstTrace: trace, secondTrace: traceContext)
    }
    
    func testEnvelopeWithData_SdkInfoIsNil_ReturnsNil() throws {
        let envelopeHeader = SentryEnvelopeHeader(id: nil, sdkInfo: nil, traceContext: nil)
        let envelope = SentryEnvelope(header: envelopeHeader, singleItem: createItemWithEmptyAttachment())
        
        let deserializedEnvelope = try XCTUnwrap(SentrySerialization.envelope(with: serializeEnvelope(envelope: envelope)))
        XCTAssertNil(deserializedEnvelope.header.sdkInfo)
    }
    
    func testEnvelopeWithData_ZeroByteItem_ReturnsEnvelope() throws {
        let itemData = Data("{}\n{\"length\":0,\"type\":\"attachment\"}\n".utf8)
        XCTAssertNotNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_EnvelopeWithHeaderAndItemWithAttachment() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       \(payloadAsString)
                       """.utf8)

        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData), "Failed to deserialize envelope")
        XCTAssertEqual(eventId, try XCTUnwrap(envelope.header.eventId))

        XCTAssertEqual(1, envelope.items.count)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(10, item.header.length)
        XCTAssertEqual("attachment", item.header.type)
        XCTAssertEqual(Data(payloadAsString.utf8), item.data)
    }
    
    func testEnvelopeWithData_LengthShorterThanPayload_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       helloworlds
                       {\"length\":10,\"type\":\"attachment\"}
                       helloworld
                       """.utf8)

        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_ItemHeaderDefinesLengthButAttachmentIsEmpty_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       
                       """.utf8)

        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_AttachmentFollowedByEmptyAttachment() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       \(payloadAsString)
                       {\"length\":0,\"type\":\"attachment\"}
                       
                       """.utf8)

        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData))
        XCTAssertEqual(eventId, try XCTUnwrap(envelope.header.eventId))

        XCTAssertEqual(2, envelope.items.count)
        
        let firstItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(10, firstItem.header.length)
        XCTAssertEqual("attachment", firstItem.header.type)
        XCTAssertNil(firstItem.header.contentType)
        XCTAssertEqual(Data(payloadAsString.utf8), firstItem.data)
        
        let secondItem = try XCTUnwrap(envelope.items[1])
        XCTAssertEqual(0, secondItem.header.length)
        XCTAssertEqual("attachment", secondItem.header.type)
        XCTAssertTrue(secondItem.data.isEmpty)
    }
    
    func testEnvelopeWithData_EmptyAttachmentFollowedByNormal() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":0,\"type\":\"attachment\"}
                       {\"length\":10,\"type\":\"attachment\"}
                       \(payloadAsString)
                       """.utf8)

        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData))
        XCTAssertEqual(eventId, try XCTUnwrap(envelope.header.eventId))

        XCTAssertEqual(2, envelope.items.count)
        
        let firstItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(0, firstItem.header.length)
        XCTAssertEqual("attachment", firstItem.header.type)
        XCTAssertNil(firstItem.header.contentType)
        XCTAssertTrue(firstItem.data.isEmpty)
        
        let secondItem = try XCTUnwrap(envelope.items[1])
        XCTAssertEqual(10, secondItem.header.length)
        XCTAssertEqual("attachment", secondItem.header.type)
        XCTAssertEqual(Data(payloadAsString.utf8), secondItem.data)
    }
    
    func testEnvelopeWithData_ItemHeaderDefinesAttachmentButNoAttachment() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        var itemData = Data()
        itemData.appendString("{\"event_id\":\"\(eventId)\"}\n")
        itemData.appendString("{\"length\":0,\"type\":\"attachment\"}\n")
        
        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData))
        XCTAssertEqual(eventId, try XCTUnwrap(envelope.header.eventId))

        XCTAssertEqual(1, envelope.items.count)
        let item = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual(0, item.header.length)
        XCTAssertEqual("attachment", item.header.type)
        XCTAssertNil(item.header.contentType)
        XCTAssertTrue(item.data.isEmpty)
    }
    
    func testEnvelopeWithData_WithAttachmentWithFileName() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"length\":10,\"type\":\"attachment\",\"filename\":\"hello.txt\"}
                       \(payloadAsString)
                       """.utf8)

        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData), "Failed to deserialize envelope")
        XCTAssertEqual(eventId, try XCTUnwrap(envelope.header.eventId))

        XCTAssertEqual(1, envelope.items.count)
        let item = try XCTUnwrap(envelope.items.first)
        
        let header = try XCTUnwrap(item.header as? SentryEnvelopeAttachmentHeader)
        XCTAssertEqual(10, header.length)
        XCTAssertEqual("attachment", header.type)
        XCTAssertEqual("hello.txt", header.filename)
        XCTAssertEqual(SentryAttachmentType.eventAttachment, header.attachmentType)
        XCTAssertNil(header.contentType)
        XCTAssertEqual(Data(payloadAsString.utf8), item.data)
    }
    
    func testEnvelopeWithData_withLogItems_shouldDeserializeLogItemFields() throws {
        let logs = Data("""
        {
            \"items\": [
                {
                    \"timestamp\":\"1969-07-20T20:18:04.000Z\",
                    \"trace_id\":\"00000000000000000000000000000000\",
                    \"level\":\"info\",
                    \"body\":\"foobar\",
                    \"attributes\":{}
                }
            ]
        }
        """.utf8)
        
        var itemData = Data()
        itemData.appendString("{}\n")
        itemData.appendString("{\"length\":\(logs.count),\"type\":\"log\",\"item_count\":1,\"content_type\":\"application/vnd.sentry.items.log+json\"}\n")
        itemData.append(logs)
        
        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: itemData), "Failed to deserialize envelope")
        
        XCTAssertEqual(1, envelope.items.count)
        let item = try XCTUnwrap(envelope.items.first)
        
        let header = try XCTUnwrap(item.header)
        XCTAssertEqual(UInt(logs.count), header.length)
        XCTAssertEqual("log", header.type)
        XCTAssertEqual(1, header.itemCount?.intValue)
        XCTAssertEqual("application/vnd.sentry.items.log+json", header.contentType)
        XCTAssertEqual(logs, item.data)
    }
    
    func testEnvelopeWithData_EmptyEnvelope_ReturnsNil() throws {
        XCTAssertNil(SentrySerialization.envelope(with: Data()))
    }
    
    func testEnvelopeWithData_CorruptHeader_ReturnsNil() throws {
        var itemData = Data()
        itemData.append(contentsOf: [0xFF, 0xFF, 0xFF]) // Invalid UTF-8 bytes
        itemData.append(Data("\n".utf8))
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_EmptyHeader_ReturnsNil() throws {
        let itemData = Data("\n".utf8)
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_EmptyItemHeader_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       
                       """.utf8)
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_EmptyItemHeaderFollowedByNewLine_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       
                       
                       """.utf8)
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_ItemHeaderWithSpace_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                        
                       """.utf8)
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_ItemHeaderWithoutType_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        let payloadAsString = "helloworld"
        
        let itemData = Data("""
                       {\"event_id\":\"\(eventId)\"}
                       {\"typ\":\"attachment\"}
                       \(payloadAsString)
                       """.utf8)
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_ItemHeaderWithoutNewLine_ReturnsNil() throws {
        let eventId = SentryId(uuidString: "12c2d058-d584-4270-9aa2-eca08bf20986")
        
        var itemData = Data()
        itemData.appendString("{\"event_id\":\"\(eventId)\"}\n")
        itemData.appendString("{\"length\":0,\"type\":\"attachment\"}")
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_CorruptItemHeader() throws {
        var itemData = Data()
        itemData.appendString("{\"event_id\":\"12c2d058-d584-4270-9aa2-eca08bf20986\"}\n")
        itemData.append(contentsOf: [0xFF]) // Invalid UTF-8 byte
        itemData.appendString("\n")
        
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_ItemWithoutType_ReturnsNil() {
        let itemData = Data("{}\n{\"length\":0}".utf8)
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_WithoutItem_ReturnsNil() {
        let itemData = Data("{}\n".utf8)
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testEnvelopeWithData_WithoutLineBreak_ReturnsNil() {
        let itemData = Data("{}".utf8)
        XCTAssertNil(SentrySerialization.envelope(with: itemData))
    }
    
    func testSerializeSession() throws {
        let dict = SentrySession(releaseName: "1.0.0", distinctId: "some-id").serialize()
        let session = try XCTUnwrap(SentrySession(jsonObject: dict))

        let data = try XCTUnwrap(SentrySerialization.data(with: session))

        XCTAssertNotNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithNoReleaseName() throws {
        var dict = SentrySession(releaseName: "1.0.0", distinctId: "some-id").serialize()
        dict["attrs"] = nil // Remove release name
        let session = try XCTUnwrap(SentrySession(jsonObject: dict))

        let data = try XCTUnwrap(SentrySerialization.data(with: session))

        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithEmptyReleaseName() throws {
        let dict = SentrySession(releaseName: "", distinctId: "some-id").serialize()
        let session = try XCTUnwrap(SentrySession(jsonObject: dict))

        let data = try XCTUnwrap(SentrySerialization.data(with: session))

        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithGarbageInDict() throws {
        var dict = SentrySession(releaseName: "", distinctId: "some-id").serialize()
        dict["started"] = "20"
        let data = try XCTUnwrap( SentrySerialization.data(withJSONObject: dict))

        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeSessionWithGarbage() throws {
        let data = try XCTUnwrap("started".data(using: .ascii))
        
        XCTAssertNil(SentrySerialization.session(with: data))
    }
    
    func testSerializeReplayRecording() {
        class MockReplayRecording: SentryReplayRecording {
            override func serialize() -> [[String: Any]] {
                return [["KEY": "VALUE"]]
            }
        }
        
        let date = Date(timeIntervalSince1970: 2)
        let recording = MockReplayRecording(segmentId: 5, size: 5_000, start: date, duration: 5_000, frameCount: 5, frameRate: 1, height: 320, width: 950, extraEvents: [])
        let data = SentrySerialization.data(with: recording)
        
        let serialized = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(serialized, "{\"segment_id\":5}\n[{\"KEY\":\"VALUE\"}]")
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
        let appStateData = try XCTUnwrap(SentrySerialization.data(withJSONObject: appState.serialize()))

        let actual = SentrySerialization.appState(with: appStateData)
        
        XCTAssertEqual(appState, actual)
    }
    
    func testAppStateWithInvalidData_ReturnsNil() throws {
        let actual = SentrySerialization.appState(with: Fixture.invalidData)
        
        XCTAssertNil(actual)
    }
    
    func testReturnNilForCorruptedEnvelope() throws {
        let envelope = SentryEnvelope(event: Event(error: NSError(domain: "test", code: -1, userInfo: nil)))
        let data = try XCTUnwrap(SentrySerialization.data(with: envelope))
        
        let corruptedData = data[0..<data.count - 1]
        
        let unserialized = SentrySerialization.envelope(with: corruptedData)
        
        XCTAssertNil(unserialized)
    }
    
    func testDeserializeArrayFromJsonData_WithValidArray_ReturnsArray() throws {
        let jsonArray = ["item1", "item2", "item3"]
        let jsonData = try XCTUnwrap(JSONSerialization.data(withJSONObject: jsonArray))
        
        let result = SentrySerialization.deserializeArray(fromJsonData: jsonData)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result as? [String], jsonArray)
    }
    
    func testDeserializeArrayFromJsonData_WithEmptyArray_ReturnsEmptyArray() throws {
        let jsonArray: [String] = []
        let jsonData = try XCTUnwrap(JSONSerialization.data(withJSONObject: jsonArray))
        
        let result = SentrySerialization.deserializeArray(fromJsonData: jsonData)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }
    
    func testDeserializeArrayFromJsonData_WithInvalidJSON_ReturnsNil() {
        let invalidJsonData = Data("invalid json".utf8)
        
        let result = SentrySerialization.deserializeArray(fromJsonData: invalidJsonData)
        
        XCTAssertNil(result)
    }
    
    func testDeserializeArrayFromJsonData_WithDictionary_ReturnsNil() throws {
        let jsonDict = ["key": "value"]
        let jsonData = try XCTUnwrap(JSONSerialization.data(withJSONObject: jsonDict))
        
        let result = SentrySerialization.deserializeArray(fromJsonData: jsonData)
        
        XCTAssertNil(result)
    }
    
    private func serializeEnvelope(envelope: SentryEnvelope) -> Data {
        var serializedEnvelope: Data = Data()
        do {
            serializedEnvelope = try XCTUnwrap(SentrySerialization.data(with: envelope))
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
    
    private func assertDefaultSdkInfoSet(deserializedEnvelope: SentryEnvelope, file: StaticString = #file, line: UInt = #line) {
        let sdkInfo = SentrySdkInfo(name: SentryMeta.sdkName, version: SentryMeta.versionString, integrations: [], features: [], packages: [])
        XCTAssertEqual(sdkInfo, deserializedEnvelope.header.sdkInfo, file: file, line: line)
    }
    
    private func assertTraceState(firstTrace: TraceContext, secondTrace: TraceContext, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(firstTrace.traceId, secondTrace.traceId, "Trace ID is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.publicKey, secondTrace.publicKey, "Public key is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.releaseName, secondTrace.releaseName, "Release name is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.environment, secondTrace.environment, "Environment is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.userSegment, secondTrace.userSegment, "User segment is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.sampleRand, secondTrace.sampleRand, "Sample rand is not equal", file: file, line: line)
        XCTAssertEqual(firstTrace.sampleRate, secondTrace.sampleRate, "Sample rate is not equal", file: file, line: line)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        self.append(Data(string.utf8))
    }
}
