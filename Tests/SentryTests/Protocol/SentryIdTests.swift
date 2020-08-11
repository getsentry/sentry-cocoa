@testable import Sentry
import XCTest

class SentryIdTests: XCTestCase {
    
    private class Fixture {
        let uuid: UUID
        let uuidString: String
        
        init() {
            uuid = UUID()
            uuidString = uuid.uuidString
        }
    }
    
    private var fixture = Fixture()
    
    func testInit() {
        XCTAssertNotEqual(SentryId(), SentryId())
    }

    func testInitWithUUID_ValidIdString() {
        let sentryId = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(fixture.uuidString, sentryId.sentryIdString)
    }
    
    func testInitWithUUIDString_ValidIdString() {
        let sentryIdWithUUIDString = SentryId(uuidString: fixture.uuidString)
        let sentryIdWithUUID = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(sentryIdWithUUID, sentryIdWithUUIDString)
    }
    
    func testInitWithInvalidUUIDString_InvalidIdString() {
        XCTAssertEqual(SentryId.empty, SentryId(uuidString: "wrong"))
    }
    
    func testInitWithEmptyUUIDString_EmptyIdString() {
        XCTAssertEqual(SentryId.empty, SentryId(uuidString: ""))
    }
    
    func testIsEqualWithSameObject() {
        let sentryId = SentryId()
        XCTAssertEqual(sentryId, sentryId)
    }
    
    func testIsNotEqualWithDifferentClass() {
        let sentryId = SentryId()
        XCTAssertFalse(sentryId.isEqual(1))
    }
    
    func testHash_IsSameWhenObjectsAreEqual() {
        let uuid = UUID()
        XCTAssertEqual(SentryId(uuid: uuid).hash, SentryId(uuid: uuid).hash)
    }
    
    func testHash_IsDifferentWhenObjectsAreDifferent() {
        XCTAssertNotEqual(SentryId(uuid: UUID()).hash, SentryId(uuid: fixture.uuid).hash)
    }
}
