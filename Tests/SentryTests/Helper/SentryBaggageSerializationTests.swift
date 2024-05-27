import Foundation
@testable import Sentry
import XCTest

class SentryBaggageSerializationTests: XCTestCase {
    
    func testDictionaryToBaggageEncoded() {
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value"]), "key=value")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value", "key2": "value2"]), "key2=value2,key=value")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value&"]), "key=value%26")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value="]), "key=value%3D")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value "]), "key=value%20")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value%"]), "key=value%25")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value-_"]), "key=value-_")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": "value\n\r"]), "key=value%0A%0D")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": ""]), "key=")
        
        let largeValue = String(repeating: "a", count: 8_188)
        
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["key": largeValue]), "key=\(largeValue)")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["AKey": "something", "BKey": largeValue]), "AKey=something")
        XCTAssertEqual(SentryBaggageSerialization.baggageEncodedDictionary(["AKey": "something", "BKey": largeValue, "CKey": "Other Value"]), "AKey=something,CKey=Other%20Value")
    }
    
    func testBaggageStringToDictionaryDecoded() {
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value"), ["key": "value"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key2=value2,key=value"), ["key": "value", "key2": "value2"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value%26"), ["key": "value&"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value%3D"), ["key": "value="])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value%20"), ["key": "value "])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value%25"), ["key": "value%"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value-_"), ["key": "value-_"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key=value%0A%0D"), ["key": "value\n\r"])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage(""), [:])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key"), [:])
        XCTAssertEqual(SentryBaggageSerialization.decodeBaggage("key="), ["key": ""])
    }
}
