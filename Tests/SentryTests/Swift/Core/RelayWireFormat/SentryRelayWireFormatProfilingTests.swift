#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class SentryRelayWireFormatProfilingTests: XCTestCase {
    func testEncodeFrame_whenAllFieldsArePresent_shouldUseProfilingWireKeys() throws {
        // -- Arrange --
        let frame = SentryRelayWireFormat.Profiling.V2.Frame(instructionAddress: "0x100001000", package: "ExampleApp", inApp: true)

        // -- Act --
        let actual = try encodedJSON(frame)

        // -- Assert --
        XCTAssertEqual(actual, #"{"in_app":true,"instruction_addr":"0x100001000","package":"ExampleApp"}"#)
    }

    func testEncodeFrame_whenOptionalFieldsAreNil_shouldOmitThem() throws {
        // -- Arrange --
        let frame = SentryRelayWireFormat.Profiling.V2.Frame(instructionAddress: "0x100001000", package: nil, inApp: nil)

        // -- Act --
        let actual = try encodedJSON(frame)

        // -- Assert --
        XCTAssertEqual(actual, #"{"instruction_addr":"0x100001000"}"#)
    }

    func testEncodeFrame_whenNotInApp_shouldPreserveFalse() throws {
        // -- Arrange --
        let frame = SentryRelayWireFormat.Profiling.V2.Frame(instructionAddress: "0x100001000", package: "System", inApp: false)

        // -- Act --
        let actual = try encodedJSON(frame)

        // -- Assert --
        XCTAssertEqual(actual, #"{"in_app":false,"instruction_addr":"0x100001000","package":"System"}"#)
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

}
