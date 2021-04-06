import XCTest

class SentryMechanismTests: XCTestCase {

    func testSerialize() {
        let mechanism = TestData.mechanism
        
        let actual = mechanism.serialize()
        
        // Changing the original doesn't modify the serialized
        mechanism.data?["other"] = "object"
        mechanism.meta = nil

        let expected = TestData.mechanism
        XCTAssertEqual(expected.type, actual["type"] as! String)
        XCTAssertEqual(expected.desc, actual["description"] as? String)
        XCTAssertEqual(expected.handled, actual["handled"] as? NSNumber)
        XCTAssertEqual(expected.helpLink, actual["help_link"] as? String)

        guard let something = (actual["data"] as? [String: Any])?["something"] as? [String: Any] else {
            XCTFail("Serialized SentryMechanism doesn't contain something.")
            return
        }

        let currentDateProvider = TestCurrentDateProvider()
        let date = currentDateProvider.date() as NSDate
        XCTAssertEqual(date.sentry_toIso8601String(), something["date"] as? String)

        XCTAssertNotNil(actual["meta"])
    }
}
