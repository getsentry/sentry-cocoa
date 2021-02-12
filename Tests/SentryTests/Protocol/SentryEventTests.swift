import XCTest

class SentryEventTests: XCTestCase {

    func testSerialize() {
        let event = TestData.event
        let actual = event.serialize()
        
        // Changing the original doesn't modify the serialized
        event.fingerprint?.append("hello")
        event.modules?["this"] = "that"
        event.breadcrumbs?.append(TestData.crumb)
        event.context?["a"] = ["a": 0]

        XCTAssertEqual(event.eventId.sentryIdString, actual["event_id"] as? String)
        XCTAssertEqual(TestData.timestampAs8601String, actual["timestamp"] as? String)
        XCTAssertEqual("cocoa", actual["platform"] as? String)
        XCTAssertEqual("info", actual["level"] as? String)

        let expected = TestData.event

        // simple properties
        XCTAssertEqual(TestData.sdk, actual["sdk"] as? [String: String])
        XCTAssertEqual(expected.releaseName, actual["release"] as? String)
        XCTAssertEqual(expected.dist, actual["dist"] as? String)
        XCTAssertEqual(expected.environment, actual["environment"] as? String)
        XCTAssertEqual(expected.transaction, actual["transaction"] as? String)
        XCTAssertEqual(expected.fingerprint, actual["fingerprint"] as? [String])
        XCTAssertNotNil(actual["user"] as? [String: Any])
        XCTAssertEqual(TestData.event.modules, actual["modules"] as? [String: String])
        XCTAssertNotNil(actual["stacktrace"] as? [String: Any])
        
        let crumbs = actual["breadcrumbs"] as? [[String: Any]]
        XCTAssertNotNil(crumbs)
        XCTAssertEqual(1, crumbs?.count)
        
        let context = actual["contexts"] as? [String: [String: Any]]
        XCTAssertEqual(1, context?.count)
        XCTAssertEqual(TestData.context["context"], context?["context"] as? [String: String])
        
        XCTAssertNotNil(actual["message"] as? [String: Any])
        
        XCTAssertEqual(expected.logger, actual["logger"] as? String)
        XCTAssertEqual(expected.serverName, actual["server_name"] as? String)
        XCTAssertEqual(expected.type, actual["type"] as? String)
    }
    
    func testSerializeWithTypeTransaction() {
        let event = TestData.event
        event.type = "transaction"
        
        let actual = event.serialize()
        XCTAssertEqual(TestData.timestampAs8601String, actual["start_timestamp"] as? String)
    }
    
    func testSerializeWithTypeTransaction_WithoutStartTimestamp() {
        let event = TestData.event
        event.type = "transaction"
        event.startTimestamp = nil
        
        let actual = event.serialize()
        XCTAssertEqual(TestData.timestampAs8601String, actual["start_timestamp"] as? String)
    }
    
    func testSerializeWithExtraTransaction() {
        let event = TestData.event
        event.transaction = nil
        let sentryTransaction = "trans"
        event.extra?["__sentry_transaction"] = sentryTransaction
        
        let actual = event.serialize()
        XCTAssertEqual(sentryTransaction, actual["transaction"] as? String)
    }
    
    func testSerializeWithoutBreadcrumbs() {
        let event = TestData.event
        event.breadcrumbs = nil
        
        let actual = event.serialize()
        XCTAssertNil(actual["breadcrumbs"])
    }
    
    func testInitWithError() {
        let error = CocoaError(CocoaError.coderInvalidValue)
        let event = Event(error: error)
        XCTAssertEqual(error, event.error as? CocoaError)
    }

    func testSerializeWithoutMessage() {
        let actual = Event().serialize()
        XCTAssertNil(actual["message"])
    }

    func testMessageIsNil() {
        XCTAssertNil(Event().message)
    }
}
