import XCTest

class SentryMechanismTests: XCTestCase {

    func testSerialize() {
        let mechanism = TestData.mechanism
        
        let actual = mechanism.serialize()
        
        // Changing the original doesn't modify the serialized
        mechanism.data?["other"] = "object"
        mechanism.meta?["other"] = "object"
        mechanism.error = nil

        let expected = TestData.mechanism
        XCTAssertEqual(expected.type, actual["type"] as! String)
        XCTAssertEqual(1, (actual["data"] as! [String: Any]).count)
        XCTAssertEqual(expected.desc, actual["description"] as? String)
        XCTAssertEqual(expected.handled, actual["handled"] as? NSNumber)
        XCTAssertEqual(expected.helpLink, actual["help_link"] as? String)
        XCTAssertEqual(1, (actual["meta"] as! [String: Any]).count)
        
        guard let error = actual["ns_error"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain ns_error")
            return
        }
        let nsError = expected.error! as NSError
        XCTAssertEqual(nsError.domain, error["domain"] as? String)
        XCTAssertEqual(nsError.code, error["code"] as? Int)
    }
}
