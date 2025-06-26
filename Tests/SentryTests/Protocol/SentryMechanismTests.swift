@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryMechanismTests: XCTestCase {

    func testSerialize() {
        let mechanism = TestData.mechanism
        
        let actual = mechanism.serialize()
        
        // Changing the original doesn't modify the serialized
        mechanism.data?["other"] = "object"
        mechanism.meta = nil

        let expected = TestData.mechanism
        XCTAssertEqual(expected.type, try XCTUnwrap(actual["type"] as? String))
        XCTAssertEqual(expected.desc, actual["description"] as? String)
        XCTAssertEqual(expected.handled, actual["handled"] as? NSNumber)
        XCTAssertEqual(expected.synthetic, actual["synthetic"] as? NSNumber)
        XCTAssertEqual(expected.helpLink, actual["help_link"] as? String)

        guard let something = (actual["data"] as? [String: Any])?["something"] as? [String: Any] else {
            XCTFail("Serialized SentryMechanism doesn't contain something.")
            return
        }

        let currentDateProvider = TestCurrentDateProvider()
        let date = currentDateProvider.date()
        XCTAssertEqual(sentry_toIso8601String(date), something["date"] as? String)

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
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let expected = TestData.mechanism
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: expected.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Mechanism?)
        
        // Assert
        XCTAssertEqual(expected.type, decoded.type)
        XCTAssertEqual(expected.desc, decoded.desc)
        XCTAssertEqual(expected.handled, decoded.handled)
        XCTAssertEqual(expected.synthetic, decoded.synthetic)
        XCTAssertEqual(expected.helpLink, decoded.helpLink)
        
        XCTAssertEqual(expected.meta?.error?.code, decoded.meta?.error?.code)
        XCTAssertEqual(expected.meta?.error?.domain, decoded.meta?.error?.domain)
    }
    
    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let expected = Mechanism(type: "type")
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: expected.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Mechanism?)
        
        // Assert
        XCTAssertEqual(expected.type, decoded.type)
        XCTAssertNil(decoded.desc)
        XCTAssertNil(decoded.handled)
        XCTAssertNil(decoded.synthetic)
        XCTAssertNil(decoded.helpLink)
        XCTAssertNil(decoded.meta?.error)
    }
}
