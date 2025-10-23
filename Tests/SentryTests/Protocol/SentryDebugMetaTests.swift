@_spi(Private) @testable import Sentry
import XCTest

class SentryDebugMetaTests: XCTestCase {

    func testSerialize() {
        // Arrange
        let debugMeta = TestData.debugMeta
        
        // Act
        let actual = debugMeta.serialize()
        
        // Assert
        XCTAssertEqual(debugMeta.debugID, actual["debug_id"] as? String)
        XCTAssertEqual(debugMeta.type, actual["type"] as? String)
        XCTAssertEqual(debugMeta.imageAddress, actual["image_addr"] as? String)
        XCTAssertEqual(debugMeta.imageSize, actual["image_size"] as? NSNumber)
        XCTAssertEqual(debugMeta.codeFile, actual["code_file"] as? String)
        XCTAssertEqual(debugMeta.imageVmAddress, actual["image_vmaddr"] as? String)
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let debugMeta = TestData.debugMeta
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMetaDecodable?)

        // Assert
        XCTAssertEqual(debugMeta.debugID, decoded.debugID)
        XCTAssertEqual(debugMeta.type, decoded.type)
        XCTAssertEqual(debugMeta.imageAddress, decoded.imageAddress)
        XCTAssertEqual(debugMeta.imageSize, decoded.imageSize)
        XCTAssertEqual(debugMeta.codeFile, decoded.codeFile)
        XCTAssertEqual(debugMeta.imageVmAddress, decoded.imageVmAddress)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let debugMeta = DebugMeta()
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMetaDecodable?)

        // Assert
        XCTAssertNil(decoded.debugID)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.imageSize)
        XCTAssertNil(decoded.codeFile)
        XCTAssertNil(decoded.imageVmAddress)
    }

    func testDecode_WithOnlyDebugID() throws {
        // Arrange
        let debugMeta = DebugMeta()
        debugMeta.debugID = "123"
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMetaDecodable?)

        // Assert
        XCTAssertEqual(debugMeta.debugID, decoded.debugID)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.imageSize)
        XCTAssertNil(decoded.codeFile)
        XCTAssertNil(decoded.imageVmAddress)
    }
    
}
