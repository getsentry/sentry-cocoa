@testable import Sentry
import XCTest

class SentryFrameTests: XCTestCase {

    func testSerialize() {
        // Arrange
        let frame = TestData.mainFrame

        // Act
        let actual = frame.serialize()

        // Assert
        XCTAssertEqual(frame.symbolAddress, actual["symbol_addr"] as? String)
        XCTAssertEqual(frame.fileName, actual["filename"] as? String)
        XCTAssertEqual(frame.function, actual["function"] as? String)
        XCTAssertEqual(frame.module, actual["module"] as? String)
        XCTAssertEqual(frame.lineNumber, actual["lineno"] as? NSNumber)
        XCTAssertEqual(frame.columnNumber, actual["colno"] as? NSNumber)
        XCTAssertEqual(frame.package, actual["package"] as? String)
        XCTAssertEqual(frame.imageAddress, actual["image_addr"] as? String)
        XCTAssertEqual(frame.instructionAddress, actual["instruction_addr"] as? String)
        XCTAssertEqual(frame.platform, actual["platform"] as? String)
        XCTAssertEqual(frame.inApp, actual["in_app"] as? NSNumber)
        XCTAssertEqual(frame.stackStart, actual["stack_start"] as? NSNumber)
    }

    func testDecode_WithAllProperties() throws {
        // Arrange
        let frame = TestData.mainFrame
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: frame.serialize()))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Frame?)

        // Assert
        XCTAssertEqual(frame.symbolAddress, decoded.symbolAddress)
        XCTAssertEqual(frame.fileName, decoded.fileName)
        XCTAssertEqual(frame.function, decoded.function)
        XCTAssertEqual(frame.module, decoded.module)
        XCTAssertEqual(frame.lineNumber, decoded.lineNumber)
        XCTAssertEqual(frame.columnNumber, decoded.columnNumber)
        XCTAssertEqual(frame.package, decoded.package)
        XCTAssertEqual(frame.imageAddress, decoded.imageAddress)
        XCTAssertEqual(frame.platform, decoded.platform)
        XCTAssertEqual(frame.inApp, decoded.inApp)
        XCTAssertEqual(frame.stackStart, decoded.stackStart)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let frame = Frame()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: frame.serialize()))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Frame?)

        // Assert
        XCTAssertNil(decoded.symbolAddress)
        XCTAssertNil(decoded.fileName)
        XCTAssertEqual("<redacted>", decoded.function)
        XCTAssertNil(decoded.module)
        XCTAssertNil(decoded.lineNumber)
        XCTAssertNil(decoded.columnNumber)
        XCTAssertNil(decoded.package)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.instructionAddress)
        XCTAssertNil(decoded.platform)
        XCTAssertNil(decoded.inApp)
        XCTAssertNil(decoded.stackStart)
    }

    func testSerialize_Bools() {
        SentryBooleanSerialization.test(Frame(), property: "inApp", serializedProperty: "in_app")
        SentryBooleanSerialization.test(Frame(), property: "stackStart", serializedProperty: "stack_start")
    }
}
