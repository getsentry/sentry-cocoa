import XCTest

class SentrySpanIdTests: XCTestCase {
    
    private class Fixture {
        let uuid: UUID
        let uuidV4String: String
        let expectedUUIDV4String: String
        
        init() {
            uuid = UUID()
            uuidV4String = String(uuid.uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
            expectedUUIDV4String = uuidV4String.lowercased()
        }
    }
    
    private var fixture = Fixture()
    
    func testInit() {
        XCTAssertNotEqual(SpanId(), SpanId())
    }
    
    func testInitWithUUID_ValidIdString() {
        let spanId = SpanId(uuid: fixture.uuid)
        
        XCTAssertEqual(fixture.expectedUUIDV4String, spanId.sentrySpanIdString)
    }
    
    func testDescriptionEqualsIdString() {
        let spanId = SpanId()
        XCTAssertEqual(spanId.description, spanId.sentrySpanIdString)
    }
      
    func testInitWithUUIDV4String_ValidIdString() {
        let spanIdWithUUIDString = SpanId(value: fixture.uuidV4String)
        let spanIdWithUUID = SpanId(uuid: fixture.uuid)
        
        XCTAssertEqual(spanIdWithUUID, spanIdWithUUIDString)
    }
    
    func testInitWithUUIDV4LowercaseString_ValidIdString() {
        let spanIdWithUUIDString = SpanId(value: fixture.expectedUUIDV4String)
        let spanIdWithUUID = SpanId(uuid: fixture.uuid)
        
        XCTAssertEqual(spanIdWithUUIDString, spanIdWithUUID)
    }
    
    func testInitWithInvalidUUIDString_InvalidIdString() {
        XCTAssertEqual(SpanId.empty, SpanId(value: "wrong"))
    }
    
    func testInitWithInvalidUUIDString36Chars_InvalidIdString() {
        XCTAssertEqual(SpanId.empty, SpanId(value: "0000000000000000"))
    }
    
    func testInitWithEmptyUUIDString_EmptyIdString() {
        XCTAssertEqual(SpanId.empty, SpanId(value: ""))
    }
    
    func testIsEqualWithSameObject() {
        let spanId = SpanId()
        XCTAssertEqual(spanId, spanId)
    }
    
    func testIsNotEqualWithDifferentClass() {
        let spanId = SpanId()
        XCTAssertFalse(spanId.isEqual(1))
    }
    
    func testHash_IsSameWhenObjectsAreEqual() {
        let uuid = UUID()
        XCTAssertEqual(SpanId(uuid: uuid).hash, SpanId(uuid: uuid).hash)
    }
    
    func testHash_IsDifferentWhenObjectsAreDifferent() {
        XCTAssertNotEqual(SpanId(uuid: UUID()).hash, SpanId(uuid: fixture.uuid).hash)
    }
}
