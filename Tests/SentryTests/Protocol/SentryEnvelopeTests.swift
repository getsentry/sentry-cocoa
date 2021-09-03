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
            get {
                let crumb = Breadcrumb(level: SentryLevel.debug, category: "ui.lifecycle")
                crumb.message = "first breadcrumb"
                return crumb
            }
        }

        var event: Event {
            let event = Event()
            event.level = SentryLevel.info
            event.message = SentryMessage(formatted: "Don't do this")
            event.releaseName = "releaseName1.0.0"
            event.environment = "save the environment"
            event.sdk = ["version": sdkVersion]
            return event
        }

        var eventWithFaultyContext: Event {
            let event = self.event
            event.context = ["dont": ["dothis": Date()]]
            return event
        }

        var eventWithFaultySDK: Event {
            let event = self.event
            event.sdk = ["dont": ["dothis": Date()]]
            return event
        }

        var eventWithFaultyContextAndBreadrumb: Event {
            let event = eventWithFaultyContext
            event.breadcrumbs = [breadcrumb]
            return event
        }

        var eventWithContinousSerializationFailure: Event {
            let event = EventSerilazationFailure()
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
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
    }
    
    override func tearDown() {
        super.tearDown()
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: fixture.path) {
                try fileManager.removeItem(atPath: fixture.path)
            }
        } catch {
            XCTFail("Couldn't delete files.")
        }
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
        let allNil = SentryEnvelopeHeader(id: nil, andSdkInfo: nil)
        XCTAssertNil(allNil.eventId)
        XCTAssertNil(allNil.sdkInfo)
    }
    
    func testInitSentryEnvelopeHeader_SetIdAndSdkInfo() {
        let eventId = SentryId()
        let sdkInfo = SentrySdkInfo(name: "sdk", andVersion: "1.2.3-alpha.0")
        
        let envelopeHeader = SentryEnvelopeHeader(id: eventId, andSdkInfo: sdkInfo)
        XCTAssertEqual(eventId, envelopeHeader.eventId)
        XCTAssertEqual(sdkInfo, envelopeHeader.sdkInfo)
    }
    
    func testInitSentryEnvelopeWithSession_DefaultSdkInfoIsSet() {
        let envelope = SentryEnvelope(session: SentrySession(releaseName: "1.1.1"))
        
        XCTAssertEqual(defaultSdkInfo, envelope.header.sdkInfo)
    }

    func testInitWithEvent() throws {
        let event = fixture.event
        let envelope = SentryEnvelope(event: event)

        let expectedData = try SentrySerialization.data(withJSONObject: event.serialize())

        XCTAssertEqual(event.eventId, envelope.header.eventId)
        XCTAssertEqual(1, envelope.items.count)
        let actual = String(data: envelope.items.first?.data ?? Data(), encoding: .utf8)?.sorted()
        let expected = String(data: expectedData, encoding: .utf8)?.sorted()
        XCTAssertEqual(expected, actual)
    }

    func testInitWithEvent_FaultyContextNoBreadcrumbs_SendsEventWithBreadcrumb() {
        let event = fixture.eventWithFaultyContext
        let envelope = SentryEnvelope(event: event)

        XCTAssertEqual(1, envelope.items.count)
        XCTAssertNotNil(envelope.items.first?.data)
        if let data = envelope.items.first?.data {
            let json = String(data: data, encoding: .utf8) ?? ""
            assertContainsBreadcrumbForDroppingContextAndSDK(json)
            assertEventDoesNotContainContext(json)
        }
    }

    func testInitWithEvent_FaultySDKNoBreadcrumbs_SendsEventWithBreadcrumb() {
        let event = fixture.eventWithFaultySDK
        let envelope = SentryEnvelope(event: event)

        XCTAssertEqual(1, envelope.items.count)
        XCTAssertNotNil(envelope.items.first?.data)
        if let data = envelope.items.first?.data {
            let json = String(data: data, encoding: .utf8) ?? ""
            assertContainsBreadcrumbForDroppingContextAndSDK(json)
            assertEventDoesNotContainContext(json)
        }
    }

    func testInitWithEvent_FaultyContextAndBreadcrumb_SendsEventWithBreadcrumbs() {
        let event = fixture.eventWithFaultyContextAndBreadrumb

        let envelope = SentryEnvelope(event: event)

        XCTAssertEqual(1, envelope.items.count)
        XCTAssertNotNil(envelope.items.first?.data)
        if let data = envelope.items.first?.data {
            let json = String(data: data, encoding: .utf8) ?? ""

            assertContainsBreadcrumbForDroppingContextAndSDK(json)
            assertEventDoesNotContainContext(json)

            json.assertContains(fixture.breadcrumb.message!, "breadrumb message")
        }
    }

    func testInitWithEvent_SerializationFails_SendsEventWithSerializationFailure() {
        let event = fixture.eventWithContinousSerializationFailure
        let envelope = SentryEnvelope(event: event)

        XCTAssertEqual(1, envelope.items.count)
        XCTAssertNotNil(envelope.items.first?.data)
        if let data = envelope.items.first?.data {
            let json = String(data: data, encoding: .utf8) ?? ""

            json.assertContains("JSON conversion error for event with message: '\(event.message?.description ?? "")'", "message")
            json.assertContains("warning", "level")
            json.assertContains(event.releaseName ?? "", "releaseName")
            json.assertContains(event.environment ?? "", "environment")
            
            json.assertContains(String(format: "%.0f", CurrentDate.date().timeIntervalSince1970), "timestamp")
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
        
        let expectedData = try SentrySerialization.data(withJSONObject: userFeedback.serialize())

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
        
        XCTAssertEqual("attachment", envelopeItem.header.type)
        XCTAssertEqual(UInt(fixture.data?.count ?? 0), envelopeItem.header.length)
        XCTAssertEqual(attachment.filename, envelopeItem.header.filename)
        XCTAssertEqual(attachment.contentType, envelopeItem.header.contentType)
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

    private func assertContainsBreadcrumbForDroppingContextAndSDK(_ json: String) {
        json.assertContains("A value set to the context or sdk is not serializable. Dropping context and sdk.", "breadcrumb message")

        json.assertContains("\"category\":\"sentry.event\"", "breadcrumb category")
        json.assertContains("\"type\":\"error\"", "breadcrumb type")
        json.assertContains("\"level\":\"error\"", "breadcrumb level")
    }

    private func assertEventDoesNotContainContext(_ json: String) {
        XCTAssertFalse(json.contains("\"contexts\":{"))
    }

    private class EventSerilazationFailure: Event {
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
