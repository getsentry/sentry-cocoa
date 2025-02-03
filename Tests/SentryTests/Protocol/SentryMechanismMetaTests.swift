@testable import Sentry
import SentryTestUtils
import XCTest

class SentryMechanismMetaTests: XCTestCase {

    func testSerialize() throws {
        let sut = TestData.mechanismMeta
        
        let actual = sut.serialize()
        
        // Changing the original doesn't modify the serialized
        sut.error = nil
        sut.machException = nil
        sut.signal = nil
        
        let expected = TestData.mechanismMeta
        
        let error = try XCTUnwrap(actual["ns_error"] as? [String: Any])
        
        let nsError = try XCTUnwrap(expected.error)
        XCTAssertEqual(nsError.domain, error["domain"] as? String)
        XCTAssertEqual(nsError.code, error["code"] as? Int)
    
        try assertSignal(actual: actual["signal"] as? [String: Any], expected: expected.signal)

        try assertMachException(actual: actual["mach_exception"] as? [String: Any], expected: expected.machException)
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
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let sut = TestData.mechanismMeta
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: sut.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as MechanismMeta?)
        
        // Assert
        try assertSignal(actual: decoded.signal, expected: sut.signal)
        try assertMachException(actual: decoded.machException, expected: sut.machException)
        XCTAssertEqual(sut.error?.code, decoded.error?.code)
    }
    
    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let sut = TestData.mechanismMeta
        sut.signal = nil
        sut.machException = nil
        sut.error = nil

        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: sut.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as MechanismMeta?)   

        // Assert
        XCTAssertNil(decoded.signal)
        XCTAssertNil(decoded.machException)
        XCTAssertNil(decoded.error)
    }
    
    private func assertSignal(actual: [String: Any]?, expected: [String: Any]?) throws {
        let actualNonNil = try XCTUnwrap(actual)
        let expectedNonNil = try XCTUnwrap(expected)
        
        XCTAssertEqual(expectedNonNil["number"] as? Int, actualNonNil["number"] as? Int)
        XCTAssertEqual(expectedNonNil["code"] as? Int, actualNonNil["code"] as? Int)
        XCTAssertEqual(expectedNonNil["name"] as? String, actualNonNil["name"] as? String)
        XCTAssertEqual(expectedNonNil["code_name"] as? String, actualNonNil["code_name"] as? String)
    }
    
    private func assertMachException(actual: [String: Any]?, expected: [String: Any]?) throws {
        let actualNonNil = try XCTUnwrap(actual)
        let expectedNonNil = try XCTUnwrap(expected)
        
        XCTAssertEqual(expectedNonNil["name"] as? String, actualNonNil["name"] as? String)
        XCTAssertEqual(expectedNonNil["exception"] as? Int, actualNonNil["exception"] as? Int)
        XCTAssertEqual(expectedNonNil["subcode"] as? Int, actualNonNil["subcode"] as? Int)
        XCTAssertEqual(expectedNonNil["code"] as? Int, actualNonNil["code"] as? Int)
    }

}
