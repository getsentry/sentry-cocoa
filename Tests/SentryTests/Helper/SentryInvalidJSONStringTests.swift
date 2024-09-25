import XCTest

final class SentryInvalidJSONStringTests: XCTestCase {

    func testDefaultInit_ReturnsInvalidJSONObject() throws {
        let sut = SentryInvalidJSONString()
        
        let array = [sut]
        XCTAssertFalse(JSONSerialization.isValidJSONObject(array))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(array))
    }
    
    func testInitWithInvocations_ReturnsValidJSONUntilInvocationsReached() {
        let sut = SentryInvalidJSONString(lengthInvocationsToBeInvalid: 2)
        
        let array = [sut]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(array))
        XCTAssertTrue(JSONSerialization.isValidJSONObject(array))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(array))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(array))
    }
}
