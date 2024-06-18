import Nimble
import XCTest

class SentryUserFeedbackTests: XCTestCase {
    
    func testPropertiesAreSetToEmptyString() {
        let userFeedback = UserFeedback(eventId: SentryId())
        
        expect(userFeedback.comments).to(beEmpty())
        expect(userFeedback.email).to(beEmpty())
        expect(userFeedback.name).to(beEmpty())
    }
    
    func testSerialize() {
        let userFeedback = UserFeedback(eventId: SentryId())
        userFeedback.comments = "Fix this please."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        
        let actual = userFeedback.serialize()
        
        expect(actual["event_id"] as? String).to(match(userFeedback.eventId.sentryIdString))
        expect(actual["comments"] as? String).to(match(userFeedback.comments))
        expect(actual["email"] as? String).to(match(userFeedback.email))
        expect(actual["name"] as? String).to(match(userFeedback.name))
    }
    
    func testSerialize_WithoutSettingProperties_AllAreEmptyStrings() {
        let userFeedback = UserFeedback(eventId: SentryId())
        
        let actual = userFeedback.serialize()
        
        expect(actual["comments"] as? String).to(beEmpty())
        expect(actual["email"] as? String).to(beEmpty())
        expect(actual["name"] as? String).to(beEmpty())
    }
}
