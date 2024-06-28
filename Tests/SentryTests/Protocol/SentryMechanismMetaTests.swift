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
        XCTAssertEqual(try XCTUnwrap(expected.signal?["number"] as? Int), try XCTUnwrap(signal["number"] as? Int))
        XCTAssertEqual(try XCTUnwrap(expected.signal?["code"] as? Int), try XCTUnwrap(signal["code"] as? Int))
        XCTAssertEqual(try XCTUnwrap(expected.signal?["name"] as? String), try XCTUnwrap(signal["name"] as? String))
        XCTAssertEqual(try XCTUnwrap(expected.signal?["code_name"] as? String), try XCTUnwrap(signal["code_name"] as? String))
        
        guard let machException = actual["mach_exception"] as? [String: Any] else {
            XCTFail("The serialization doesn't contain mach_exception")
            return
        }
        XCTAssertEqual(try XCTUnwrap(expected.machException?["name"] as? String), try XCTUnwrap(machException["name"] as? String))
        XCTAssertEqual(try XCTUnwrap(expected.machException?["exception"] as? Int), try XCTUnwrap(machException["exception"] as? Int))
        XCTAssertEqual(try XCTUnwrap(expected.machException?["subcode"] as? Int), try XCTUnwrap(machException["subcode"] as? Int))
        XCTAssertEqual(try XCTUnwrap(expected.machException?["code"] as? Int), try XCTUnwrap(machException["code"] as? Int))
    }
    
    func testSerialize_CallsSanitize() {
        let sut = MechanismMeta()
        sut.machException = ["a": self]
        sut.signal = ["a": self]
        
        let actual = sut.serialize()
        
        XCTAssertNotNil(actual)
        
        let machException = actual["mach_exception"] as? [String: Any]
        XCTAssertEqual(self.description, try XCTUnwrap(machException?["a"]  as? String))
        
        let signal = actual["signal"] as? [String: Any]
        XCTAssertEqual(self.description, try XCTUnwrap(signal?["a"]  as? String))
    }

}
