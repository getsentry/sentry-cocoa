import XCTest

class SentryUserFeedbackTests: XCTestCase {
    
    func testPropertiesAreSetToEmptyString() {
        let userFeedback = UserFeedback(eventId: SentryId())
        
        XCTAssertEqual("", userFeedback.comments)
        XCTAssertEqual("", userFeedback.email)
        XCTAssertEqual("", userFeedback.name)
    }
    
    func testSerialize() {
        let userFeedback = UserFeedback(eventId: SentryId())
        userFeedback.comments = "Fix this please."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        
        let actual = userFeedback.serialize()
        
        XCTAssertEqual(userFeedback.eventId.sentryIdString, actual["event_id"] as? String)
        XCTAssertEqual(userFeedback.comments, actual["comments"] as? String)
        XCTAssertEqual(userFeedback.email, actual["email"] as? String)
        XCTAssertEqual(userFeedback.name, actual["name"] as? String)
    }
    
    func testSerialize_WithoutSettingProperties_AllAreEmptyStrings() {
        let userFeedback = UserFeedback(eventId: SentryId())
        
        let actual = userFeedback.serialize()
        
        XCTAssertEqual("", actual["comments"] as? String)
        XCTAssertEqual("", actual["email"] as? String)
        XCTAssertEqual("", actual["name"] as? String)
    }
}
