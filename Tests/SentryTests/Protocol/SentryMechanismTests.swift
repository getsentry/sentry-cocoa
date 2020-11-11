import XCTest

class SentryMechanismTests: XCTestCase {

    func testSerialize() {
        let mechanism = TestData.mechanism
        
        let actual = mechanism.serialize()
        
        // Changing the original doesn't modify the serialized
        mechanism.data?["other"] = "object"
        mechanism.meta?["other"] = "object"

        let expected = TestData.mechanism
        XCTAssertEqual(expected.type, actual["type"] as! String)
        XCTAssertEqual(1, (actual["data"] as! [String: Any]).count)
        XCTAssertEqual(expected.desc, actual["description"] as? String)
        XCTAssertEqual(expected.handled, actual["handled"] as? NSNumber)
        XCTAssertEqual(expected.helpLink, actual["help_link"] as? String)
        XCTAssertEqual(1, (actual["meta"] as! [String: Any]).count)
    }
}
