import _SentryPrivate
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

class SentryEnvelopeTests: XCTestCase {
    
    private class Fixture {
        let sdkVersion = "sdkVersion"
        let userFeedback: UserFeedback
        let path = "test.log"
        let data = "hello".data(using: .utf8)
        
        let maxAttachmentSize: UInt = 5 * 1_024 * 1_024
        let dataAllowed: Data
        let dataTooBig: Data
        
        init() {
            userFeedback = UserFeedback(eventId: SentryId())
            userFeedback.comments = "It doesn't work!"
            userFeedback.email = "john@me.com"
            userFeedback.name = "John Me"
            
            dataAllowed = Data([UInt8](repeating: 1, count: Int(maxAttachmentSize)))
            dataTooBig = Data([UInt8](repeating: 1, count: Int(maxAttachmentSize) + 1))
        }

        var breadcrumb: Breadcrumb {
            let crumb = Breadcrumb(level: SentryLevel.debug, category: "ui.lifecycle")
            crumb.message = "first breadcrumb"
            return crumb
        }

        var event: Event {
            let event = Event()
            event.level = SentryLevel.info
            event.message = SentryMessage(formatted: "Don't do this")
            event.releaseName = "releaseName1.0.0"
            event.environment = "save the environment"
            event.sdk = ["version": sdkVersion, "date": Date()]
            return event
        }

        var eventWithContinousSerializationFailure: Event {
            let event = EventSerializationFailure()
            event.message = SentryMessage(formatted: "Failure")
            event.releaseName = "release"
            event.environment = "environment"
            event.platform = "platform"
            return event
        }
    }

    private let fixture = Fixture()

    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().dateProvider = TestCurrentDateProvider()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fixture.path) {
            try fileManager.removeItem(atPath: fixture.path)
        }
        clearTestState()
    }

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
        
        let envelopeId = SentryId()
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

        let envelopeId = SentryId()
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
        let allNil = SentryEnvelopeHeader(id: nil, sdkInfo: nil, traceContext: nil)
        XCTAssertNil(allNil.eventId)
        XCTAssertNil(allNil.sdkInfo)
        XCTAssertNil(allNil.traceContext)
    }
    
    func testInitSentryEnvelopeHeader_IdAndTraceStateNil() {
        let allNil = SentryEnvelopeHeader(id: nil, traceContext: nil)
        XCTAssertNil(allNil.eventId)
        XCTAssertNotNil(allNil.sdkInfo)
        XCTAssertNil(allNil.traceContext)
    }
    
    func testInitSentryEnvelopeHeader_SetIdAndSdkInfo() {
        let eventId = SentryId()
        let sdkInfo = SentrySdkInfo(name: "sdk", andVersion: "1.2.3-alpha.0")
        
        let envelopeHeader = SentryEnvelopeHeader(id: eventId, sdkInfo: sdkInfo, traceContext: nil)
        XCTAssertEqual(eventId, envelopeHeader.eventId)
        XCTAssertEqual(sdkInfo, envelopeHeader.sdkInfo)
    }
    
    func testInitSentryEnvelopeHeader_SetIdAndTraceState() {
        let eventId = SentryId()
        let traceContext = SentryTraceContext(trace: SentryId(), publicKey: "publicKey", releaseName: "releaseName", environment: "environment", transaction: "transaction", userSegment: nil, sampleRate: nil, sampled: nil)
        
        let envelopeHeader = SentryEnvelopeHeader(id: eventId, traceContext: traceContext)
        XCTAssertEqual(eventId, envelopeHeader.eventId)
        XCTAssertEqual(traceContext, envelopeHeader.traceContext)
    }
    
    func testInitSentryEnvelopeWithSession_DefaultSdkInfoIsSet() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.1.1", distinctId: "some-id"))
        
        XCTAssertEqual(defaultSdkInfo, envelope.header.sdkInfo)
    }

    func testInitWithEvent() throws {
        let event = fixture.event
        let envelope = SentryEnvelope(event: event)

        let expectedData = SentrySerialization.data(withJSONObject: event.serialize())!

        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        let actual = String(data: envelope.items.first?.data ?? Data(), encoding: .utf8)?.sorted()
        let expected = String(data: expectedData, encoding: .utf8)?.sorted()
        XCTAssertEqual(expected, actual)
    }

    func testInitWithEvent_SerializationFails_SendsEventWithSerializationFailure() {
        let event = fixture.eventWithContinousSerializationFailure
        let envelope = SentryEnvelope(event: event)

        XCTAssertEqual(1, envelope.items.count)
        XCTAssertNotNil(envelope.items.first?.data)
        if let data = envelope.items.first?.data {
            let json = String(data: data, encoding: .utf8) ?? ""

            // Asserting the description of the message doesn't work properly, because
            // the serialization adds \n. Therefore, we only check for bits of the
            // the description. The actual description is tested in the tests for the
            // SentryMessage
            json.assertContains("JSON conversion error for event with message: '<SentryMessage: ", "message")
            json.assertContains("formatted = \(event.message?.formatted ?? "")", "message")
            
            json.assertContains("warning", "level")
            json.assertContains(event.releaseName ?? "", "releaseName")
            json.assertContains(event.environment ?? "", "environment")
            
            json.assertContains(String(format: "%.0f", SentryDependencyContainer.sharedInstance().dateProvider.date().timeIntervalSince1970), "timestamp")
        }
    }
    
    func testInitWithUserFeedback() throws {
        let userFeedback = fixture.userFeedback
        
        let envelope = SentryEnvelope(userFeedback: userFeedback)
        XCTAssertEqual(userFeedback.eventId, envelope.header.eventId)
        XCTAssertEqual(defaultSdkInfo, envelope.header.sdkInfo)
        
        XCTAssertEqual(1, envelope.items.count)
        let item = envelope.items.first
        XCTAssertEqual("user_report", item?.header.type)
        XCTAssertNotNil(item?.data)
        
        let expectedData = SentrySerialization.data(withJSONObject: userFeedback.serialize())!

        let actual = String(data: item?.data ?? Data(), encoding: .utf8)?.sorted()
        let expected = String(data: expectedData, encoding: .utf8)?.sorted()
        XCTAssertEqual(expected, actual)
    }
    
    func testInitWithDataAttachment() {
        let attachment = TestData.dataAttachment
        
        let envelopeItem = SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: fixture.maxAttachmentSize)!
        
        XCTAssertEqual("attachment", envelopeItem.header.type)
        XCTAssertEqual(UInt(attachment.data?.count ?? 0), envelopeItem.header.length)
        XCTAssertEqual(attachment.filename, envelopeItem.header.filename)
        XCTAssertEqual(attachment.contentType, envelopeItem.header.contentType)
    }
    
    func testInitWithFileAttachment() {
        writeDataToFile(data: fixture.data ?? Data())
        
        let attachment = Attachment(path: fixture.path)
        
        let envelopeItem = SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: fixture.maxAttachmentSize)!

        guard let header = envelopeItem.header as? SentryEnvelopeAttachmentHeader else {
            XCTFail("Header should be SentryEnvelopeAttachmentHeader")
            return
        }

        XCTAssertEqual(header.attachmentType, .eventAttachment)
        XCTAssertEqual("attachment", envelopeItem.header.type)
        XCTAssertEqual(UInt(fixture.data?.count ?? 0), envelopeItem.header.length)
        XCTAssertEqual(attachment.filename, envelopeItem.header.filename)
        XCTAssertEqual(attachment.contentType, envelopeItem.header.contentType)
    }

    func testInitWith_ViewHierarchy_Attachment() {
        writeDataToFile(data: fixture.data ?? Data())

        let attachment = Attachment(path: fixture.path, filename: "filename", contentType: "text", attachmentType: .viewHierarchy)

        let envelopeItem = SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: fixture.maxAttachmentSize)!
        guard let header = envelopeItem.header as? SentryEnvelopeAttachmentHeader else {
            XCTFail("Header should be SentryEnvelopeAttachmentHeader")
            return
        }

        XCTAssertEqual(header.attachmentType, .viewHierarchy)
    }
    
    func testInitWithNonExistentFileAttachment() {
        let attachment = Attachment(path: fixture.path)
        
        let envelopeItem = SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: fixture.maxAttachmentSize)
        
        XCTAssertNil(envelopeItem)
    }
    
    func testInitWithFileAttachment_MaxAttachmentSize() {
        writeDataToFile(data: fixture.dataAllowed)
        XCTAssertNotNil(SentryEnvelopeItem(attachment: Attachment(path: fixture.path), maxAttachmentSize: fixture.maxAttachmentSize))
        
        writeDataToFile(data: fixture.dataTooBig)
        XCTAssertNil(SentryEnvelopeItem(attachment: Attachment(path: fixture.path), maxAttachmentSize: fixture.maxAttachmentSize))
    }

    func test_SentryEnvelopeAttachmentHeaderSerialization() {
        let header = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10, filename: "SomeFileName", contentType: "SomeContentType", attachmentType: .viewHierarchy)

        let data = header.serialize()
        XCTAssertEqual(data["type"] as? String, "SomeType")
        XCTAssertEqual(data["length"] as? Int, 10)
        XCTAssertEqual(data["filename"] as? String, "SomeFileName")
        XCTAssertEqual(data["content_type"] as? String, "SomeContentType")
        XCTAssertEqual(data["attachment_type"] as? String, "event.view_hierarchy")
        XCTAssertEqual(data.count, 5)

        let header2 = SentryEnvelopeAttachmentHeader(type: "SomeType", length: 10)

        let data2 = header2.serialize()
        XCTAssertEqual(data2["type"] as? String, "SomeType")
        XCTAssertEqual(data2["length"] as? Int, 10)
        XCTAssertNil(data2["filename"])
        XCTAssertNil(data2["content_type"])
        XCTAssertEqual(data2["attachment_type"] as? String, "event.attachment")
        XCTAssertEqual(data2.count, 3)
    }

    func test_SentryEnvelopeItemHeaderSerialization_DefaultInit() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10)

        let data = header.serialize()
        expect(data.count) == 2
        XCTAssertEqual(data.count, 2)
        expect(data["type"] as? String) == "SomeType"
        expect(data["length"] as? Int) == 10
        expect(data["filename"]) == nil
        expect(data["content_type"]) == nil
    }
    
    func test_SentryEnvelopeItemHeaderSerialization_WithoutFileName() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, contentType: "text/html")

        let data = header.serialize()
        expect(data["type"] as? String) == "SomeType"
        expect(data["length"] as? Int) == 10
        expect(data["filename"]) == nil
        expect(data["content_type"] as? String) == "text/html"
        expect(data.count) == 3
    }
    
    func test_SentryEnvelopeItemHeaderSerialization_AllParameters() {
        let header = SentryEnvelopeItemHeader(type: "SomeType", length: 10, filenname: "SomeFileName", contentType: "text/html")
        
        let data = header.serialize()
        expect(data["type"] as? String) == "SomeType"
        expect(data["length"] as? Int) == 10
        expect(data["filename"] as? String) == "SomeFileName"
        expect(data["content_type"] as? String) == "text/html"
        expect(data.count) == 4
    }
    
    func testInitWithDataAttachment_MaxAttachmentSize() {
        let attachmentTooBig = Attachment(data: fixture.dataTooBig, filename: "")
        XCTAssertNil(
            SentryEnvelopeItem(attachment: attachmentTooBig, maxAttachmentSize: fixture.maxAttachmentSize))
        
        let attachment = Attachment(data: fixture.dataAllowed, filename: "")
        XCTAssertNotNil(
            SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: fixture.maxAttachmentSize))
    }
    
    private func writeDataToFile(data: Data) {
        do {
            try data.write(to: URL(fileURLWithPath: fixture.path))
        } catch {
            XCTFail("Failed to store attachment.")
        }
    }

    private func assertEventDoesNotContainContext(_ json: String) {
        XCTAssertFalse(json.contains("\"contexts\":{"))
    }

    private class EventSerializationFailure: Event {
        override func serialize() -> [String: Any] {
            return ["is going": ["to fail": Date()]]
        }
    }
}

fileprivate extension String {
    func assertContains(_ value: String, _ fieldName: String) {
        XCTAssertTrue(self.contains(value), "The JSON doesn't contain the \(fieldName): '\(value)' \n \(self)")
    }
}
