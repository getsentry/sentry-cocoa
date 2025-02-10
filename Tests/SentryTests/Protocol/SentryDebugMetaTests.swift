@testable import Sentry
import XCTest

class SentryDebugMetaTests: XCTestCase {

    func testSerialize() {
        // Arrange
        let debugMeta = TestData.debugMeta
        
        // Act
        let actual = debugMeta.serialize()
        
        // Assert
        XCTAssertEqual(debugMeta.uuid, actual["uuid"] as? String)
        XCTAssertEqual(debugMeta.debugID, actual["debug_id"] as? String)
        XCTAssertEqual(debugMeta.type, actual["type"] as? String)
        XCTAssertEqual(debugMeta.imageAddress, actual["image_addr"] as? String)
        XCTAssertEqual(debugMeta.imageSize, actual["image_size"] as? NSNumber)
        XCTAssertEqual((debugMeta.name! as NSString).lastPathComponent, actual["name"] as? String)
        XCTAssertEqual(debugMeta.codeFile, actual["code_file"] as? String)
        XCTAssertEqual(debugMeta.imageVmAddress, actual["image_vmaddr"] as? String)
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let debugMeta = TestData.debugMeta
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMeta?)

        // Assert
        XCTAssertEqual(debugMeta.uuid, decoded.uuid)
        XCTAssertEqual(debugMeta.debugID, decoded.debugID)
        XCTAssertEqual(debugMeta.type, decoded.type)
        XCTAssertEqual(debugMeta.imageAddress, decoded.imageAddress)
        XCTAssertEqual(debugMeta.imageSize, decoded.imageSize)
        XCTAssertEqual((debugMeta.name! as NSString).lastPathComponent, decoded.name)
        XCTAssertEqual(debugMeta.codeFile, decoded.codeFile)
        XCTAssertEqual(debugMeta.imageVmAddress, decoded.imageVmAddress)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let debugMeta = DebugMeta()
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMeta?)

        // Assert
        XCTAssertNil(decoded.uuid)
        XCTAssertNil(decoded.debugID)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.imageSize)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.codeFile)
        XCTAssertNil(decoded.imageVmAddress)
    }

    func testDecode_WithOnlyUuid() throws {
        // Arrange
        let debugMeta = DebugMeta()
        debugMeta.uuid = "123"
        let actual = debugMeta.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as DebugMeta?)

        // Assert
        XCTAssertEqual(debugMeta.uuid, decoded.uuid)
        XCTAssertNil(decoded.debugID)
        XCTAssertNil(decoded.type)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.imageSize)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.codeFile)
        XCTAssertNil(decoded.imageVmAddress)
    }
    
}
