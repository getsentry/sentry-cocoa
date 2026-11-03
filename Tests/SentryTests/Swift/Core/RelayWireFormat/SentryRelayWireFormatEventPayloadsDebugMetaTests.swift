#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class SentryRelayWireFormatEventPayloadsDebugMetaTests: XCTestCase {
    func testEncodeDebugImage_whenAllFieldsArePresent_shouldUseDebugMetaWireKeys() throws {
        // -- Arrange --
        let image = SentryRelayWireFormat.EventPayloads.DebugMeta.Image(
            type: "macho", debugID: "84a04d24-0e60-3810-a8c0-90a65e2df61a", codeFile: "/usr/lib/Example",
            imageAddress: "0x100000000", imageSize: 8_192, imageVmAddress: "0x40000"
        )

        // -- Act --
        let actual = try encodedJSON(image)

        // -- Assert --
        XCTAssertEqual(actual, #"{"code_file":"/usr/lib/Example","debug_id":"84a04d24-0e60-3810-a8c0-90a65e2df61a","image_addr":"0x100000000","image_size":8192,"image_vmaddr":"0x40000","type":"macho"}"#)
    }

    func testEncodeDebugImage_whenOptionalFieldsAreNil_shouldOmitThem() throws {
        // -- Arrange --
        let image = SentryRelayWireFormat.EventPayloads.DebugMeta.Image(
            type: "macho", debugID: "84a04d24-0e60-3810-a8c0-90a65e2df61a", codeFile: nil,
            imageAddress: "0x100000000", imageSize: nil, imageVmAddress: nil
        )

        // -- Act --
        let actual = try encodedJSON(image)

        // -- Assert --
        XCTAssertEqual(actual, #"{"debug_id":"84a04d24-0e60-3810-a8c0-90a65e2df61a","image_addr":"0x100000000","type":"macho"}"#)
    }

    func testEncodeDebugImage_whenImageSizeExceedsSignedRange_shouldRetainUnsignedInteger() throws {
        // -- Arrange --
        let image = SentryRelayWireFormat.EventPayloads.DebugMeta.Image(
            type: "macho", debugID: nil, codeFile: nil, imageAddress: "0x100000000",
            imageSize: UInt64.max, imageVmAddress: nil
        )

        // -- Act --
        let actual = try encodedJSON(image)

        // -- Assert --
        XCTAssertEqual(actual, #"{"image_addr":"0x100000000","image_size":18446744073709551615,"type":"macho"}"#)
    }

    func testEncodeDebugMeta_whenImagesAreEmpty_shouldEncodeEmptyArray() throws {
        // -- Arrange --
        let metadata = SentryRelayWireFormat.EventPayloads.DebugMeta(images: [])

        // -- Act --
        let actual = try encodedJSON(metadata)

        // -- Assert --
        XCTAssertEqual(actual, #"{"images":[]}"#)
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

}
