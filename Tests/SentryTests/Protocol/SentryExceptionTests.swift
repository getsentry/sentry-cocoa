@testable import Sentry
import XCTest

class SentryExceptionTests: XCTestCase {

    func testSerialize() throws {
        let exception = TestData.exception

        let actual = exception.serialize()

        // Changing the original doesn't modify the serialized
        exception.mechanism?.desc = ""
        exception.stacktrace?.registers = [:]

        let expected = TestData.exception
        XCTAssertEqual(expected.type, try XCTUnwrap(actual["type"] as? String))
        XCTAssertEqual(expected.value, try XCTUnwrap(actual["value"] as? String))

        let mechanism = try XCTUnwrap(actual["mechanism"] as? [String: Any])
        XCTAssertEqual(TestData.mechanism.desc, mechanism["description"] as? String)

        XCTAssertEqual(expected.module, actual["module"] as? String)
        XCTAssertEqual(expected.threadId, actual["thread_id"] as? NSNumber)

        let stacktrace = try XCTUnwrap(actual["stacktrace"] as? [String: Any])
        XCTAssertEqual(TestData.stacktrace.registers, stacktrace["registers"] as? [String: String])
    }

    func testDecode_WithAllProperties() throws {
        // Arrange
        let exception = TestData.exception
        let actual = exception.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Exception?)

        // Assert
        XCTAssertEqual(exception.type, decoded.type)
        XCTAssertEqual(exception.value, decoded.value)
        XCTAssertEqual(exception.module, decoded.module)
        XCTAssertEqual(exception.threadId, decoded.threadId)

        let decodedMechanism = try XCTUnwrap(decoded.mechanism)
        let expectedMechanism = try XCTUnwrap(exception.mechanism)
        XCTAssertEqual(expectedMechanism.desc, decodedMechanism.desc)
        XCTAssertEqual(expectedMechanism.handled, decodedMechanism.handled)
        XCTAssertEqual(expectedMechanism.type, decodedMechanism.type)

        let decodedStacktrace = try XCTUnwrap(decoded.stacktrace)
        let expectedStacktrace = try XCTUnwrap(exception.stacktrace)
        XCTAssertEqual(expectedStacktrace.frames.count, decodedStacktrace.frames.count)
        XCTAssertEqual(expectedStacktrace.registers, decodedStacktrace.registers)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let exception = Exception(value: "value", type: "type")
        let actual = exception.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))

        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Exception?)

        // Assert
        XCTAssertEqual(exception.type, decoded.type)
        XCTAssertEqual(exception.value, decoded.value)
        XCTAssertNil(decoded.mechanism)
        XCTAssertNil(decoded.module)
        XCTAssertNil(decoded.threadId)
        XCTAssertNil(decoded.stacktrace)
    }
}
