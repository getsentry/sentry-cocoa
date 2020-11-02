import XCTest

class SentryUserFeedbackTests: XCTestCase {
    
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
}
