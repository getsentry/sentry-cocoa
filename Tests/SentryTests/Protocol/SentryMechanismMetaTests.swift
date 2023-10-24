import SentryTestUtils
import XCTest

class SentryMechanismMetaTests: XCTestCase {

    func testSerialize() {
        let sut = TestData.mechanismMeta
        
        let actual = sut.serialize()
        
        // Changing the original doesn't modify the serialized
        sut.error = nil
        sut.machException = nil
        sut.signal = nil
        
        let expected = TestData.mechanismMeta
        
        guard let error = actual["ns_error"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain ns_error")
            return
        }
        let nsError = expected.error! as SentryNSError
        XCTAssertEqual(Dynamic(nsError).domain, error["domain"] as? String)
        XCTAssertEqual(Dynamic(nsError).code, error["code"] as? Int)
        
        guard let signal = actual["signal"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain signal")
            return
        }
        XCTAssertEqual(expected.signal?["number"] as! Int, signal["number"] as! Int)
        XCTAssertEqual(expected.signal?["code"] as! Int, signal["code"] as! Int)
        XCTAssertEqual(expected.signal?["name"] as! String, signal["name"] as! String)
        XCTAssertEqual(expected.signal?["code_name"] as! String, signal["code_name"] as! String)
        
        guard let machException = actual["mach_exception"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain mach_exception")
            return
        }
        XCTAssertEqual(expected.machException?["name"] as! String, machException["name"] as! String)
        XCTAssertEqual(expected.machException?["exception"] as! Int, machException["exception"] as! Int)
        XCTAssertEqual(expected.machException?["subcode"] as! Int, machException["subcode"] as! Int)
        XCTAssertEqual(expected.machException?["code"] as! Int, machException["code"] as! Int)
    }
    
    func testSerialize_CallsSanitize() {
        let sut = MechanismMeta()
        sut.machException = ["a": self]
        sut.signal = ["a": self]
        
        let actual = sut.serialize()
        
        XCTAssertNotNil(actual)
        
        let machException = actual["mach_exception"] as? [String: Any]
        XCTAssertEqual(self.description, machException?["a"]  as! String)
        
        let signal = actual["signal"] as? [String: Any]
        XCTAssertEqual(self.description, signal?["a"]  as! String)
    }

}
