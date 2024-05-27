import Foundation
@testable import Sentry
import XCTest

class SentryBaggageSerializationTests: XCTestCase {
    
    func testDictionaryToBaggageEncoded() {
        XCTAssertEqual(encodeDictionary(["key": "value"]), "key=value")
        XCTAssertEqual(encodeDictionary(["key": "value", "key2": "value2"]), "key2=value2,key=value")
        XCTAssertEqual(encodeDictionary(["key": "value&"]), "key=value%26")
        XCTAssertEqual(encodeDictionary(["key": "value="]), "key=value%3D")
        XCTAssertEqual(encodeDictionary(["key": "value "]), "key=value%20")
        XCTAssertEqual(encodeDictionary(["key": "value%"]), "key=value%25")
        XCTAssertEqual(encodeDictionary(["key": "value-_"]), "key=value-_")
        XCTAssertEqual(encodeDictionary(["key": "value\n\r"]), "key=value%0A%0D")
        
        let largeValue = String(repeating: "a", count: 8_188)
        
        XCTAssertEqual(encodeDictionary(["key": largeValue]), "key=\(largeValue)")
        XCTAssertEqual(encodeDictionary(["AKey": "something", "BKey": largeValue]), "AKey=something")
        XCTAssertEqual(encodeDictionary(["AKey": "something", "BKey": largeValue, "CKey": "Other Value"]), "AKey=something,CKey=Other%20Value")
    }
    
    func testBaggageEmptyKey_ReturnsEmptyString() {
        XCTAssertEqual(encodeDictionary(["key": ""]), "")
    }
    
    func testBaggageEmptyValue_ReturnsEmptyString() {
        XCTAssertEqual(encodeDictionary(["": "value"]), "")
    }
    
    func testBaggageEmptyKeyAndValue_ReturnsEmptyString() {
        XCTAssertEqual(encodeDictionary(["": ""]), "")
    }
    
    func testBaggageStringToDictionaryDecoded() {
        XCTAssertEqual(decode("key=value"), ["key": "value"])
        XCTAssertEqual(decode("key2=value2,key=value"), ["key": "value", "key2": "value2"])
        XCTAssertEqual(decode("key=value%26"), ["key": "value&"])
        XCTAssertEqual(decode("key=value%3D"), ["key": "value="])
        XCTAssertEqual(decode("key=value%20"), ["key": "value "])
        XCTAssertEqual(decode("key=value%25"), ["key": "value%"])
        XCTAssertEqual(decode("key=value-_"), ["key": "value-_"])
        XCTAssertEqual(decode("key=value%0A%0D"), ["key": "value\n\r"])
        XCTAssertEqual(decode(""), [:])
        XCTAssertEqual(decode("key"), [:])
        XCTAssertEqual(decode("key="), ["key": ""])
    }
    
    private func encodeDictionary(_ dictionary: [String: String]) -> String {
        return SentryBaggageSerialization.encodeDictionary(dictionary)
    }
    
    private func decode(_ baggage: String) -> [String: String] {
        return SentryBaggageSerialization.decode(baggage)
    }
}
