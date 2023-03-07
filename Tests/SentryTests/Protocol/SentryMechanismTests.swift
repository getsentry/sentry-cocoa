import SentryTestUtils
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
        XCTAssertEqual(expected.synthetic, actual["synthetic"] as? NSNumber)
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
    
    func testSerialize_OnlyType_NullablePropertiesNotAdded() {
        let type = "type"
        let mechanism = Mechanism(type: type)
        
        let actual = mechanism.serialize()
        XCTAssertEqual(1, actual.count)
        XCTAssertEqual(type, actual["type"] as? String)
    }
    
    func testSerialize_Bools() {
        SentryBooleanSerialization.test(Mechanism(type: ""), property: "handled")
    }
}
