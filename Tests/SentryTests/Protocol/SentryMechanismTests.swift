import XCTest

class SentryMechanismTests: XCTestCase {

    func testSerialize() {
        let mechanism = TestData.mechanism
        
        let actual = mechanism.serialize()
        
        // Changing the original doesn't modify the serialized
        mechanism.data?["other"] = "object"
        mechanism.meta?["data"] = "object"
        mechanism.error = nil

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

        let meta = actual["meta"] as! [String: Any]
        XCTAssertEqual(2, meta.count)
        
        guard let error = meta["ns_error"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain ns_error")
            return
        }
        let nsError = expected.error! as SentryNSError
        XCTAssertEqual(nsError.domain, error["domain"] as? String)
        XCTAssertEqual(nsError.code, error["code"] as? Int)
    }
}
