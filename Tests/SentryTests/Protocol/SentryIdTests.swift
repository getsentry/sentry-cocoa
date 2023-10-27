@testable import Sentry
import XCTest

class SentryIdTests: XCTestCase {
    
    private class Fixture {
        let uuid: UUID
        let uuidV4String: String
        let expectedUUIDV4String: String
        let uuidString: String
        
        init() {
            uuid = UUID()
            uuidV4String = uuid.uuidString.replacingOccurrences(of: "-", with: "")
            expectedUUIDV4String = uuidV4String.lowercased()
            uuidString = uuid.uuidString
        }
    }
    
    private var fixture = Fixture()
    
    func testInit() {
        XCTAssertNotEqual(SentryId(), SentryId())
    }

    func testInitWithUUID_ValidIdString() {
        let sentryId = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(fixture.expectedUUIDV4String, sentryId.sentryIdString)
    }
    
    func testInitWithUUIDString_ValidIdString() {
        let sentryIdWithUUIDString = SentryId(uuidString: fixture.uuidString)
        let sentryIdWithUUID = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(sentryIdWithUUID, sentryIdWithUUIDString)
    }
    
    func testInitWithUUIDV4String_ValidIdString() {
        let sentryIdWithUUIDString = SentryId(uuidString: fixture.uuidV4String)
        let sentryIdWithUUID = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(sentryIdWithUUID, sentryIdWithUUIDString)
    }
    
    func testInitWithUUIDV4LowercaseString_ValidIdString() {
        let sentryIdWithUUIDString = SentryId(uuidString: fixture.expectedUUIDV4String)
        let sentryIdWithUUID = SentryId(uuid: fixture.uuid)
        
        XCTAssertEqual(sentryIdWithUUID, sentryIdWithUUIDString)
    }
    
    func testInitWithInvalidUUIDString_InvalidIdString() {
        XCTAssertEqual(SentryId.empty, SentryId(uuidString: "wrong"))
    }
    
    func testInitWithInvalidUUIDString36Chars_InvalidIdString() {
        XCTAssertEqual(SentryId.empty, SentryId(uuidString: "00000000-0000-0000-0000-0-0000000000"))
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
    
    func testConcurrentReadsOfEmpty() {
        testConcurrentModifications { _ in
            XCTAssertNotNil(SentryId.empty)
        }
    }
}
