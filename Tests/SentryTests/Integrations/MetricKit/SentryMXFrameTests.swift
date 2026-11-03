#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

final class SentryMXFrameTests: XCTestCase {
    func testDecode_whenOptionalFieldsMissing_shouldDecodeRequiredFields() throws {
        // -- Arrange --
        let data = Data(#"{"address":4096,"offsetIntoBinaryTextSegment":4}"#.utf8)

        // -- Act --
        let frame = try JSONDecoder().decode(SentryMXFrame.self, from: data)

        // -- Assert --
        XCTAssertEqual(frame.address, 4_096)
        XCTAssertEqual(frame.offsetIntoBinaryTextSegment, 4)
        XCTAssertNil(frame.binaryUUID)
        XCTAssertNil(frame.binaryName)
        XCTAssertNil(frame.subFrames)
        XCTAssertNil(frame.sampleCount)
    }

    func testDecode_whenNestedFramesPresent_shouldPreserveMetadata() throws {
        // -- Arrange --
        let uuid = UUID()
        let data = Data("""
        {
            "binaryUUID":"\(uuid.uuidString)",
            "binaryName":"App",
            "address":4100,
            "offsetIntoBinaryTextSegment":4,
            "sampleCount":3,
            "subFrames":[{"address":8192,"offsetIntoBinaryTextSegment":0,"sampleCount":2}]
        }
        """.utf8)

        // -- Act --
        let frame = try JSONDecoder().decode(SentryMXFrame.self, from: data)

        // -- Assert --
        XCTAssertEqual(frame.binaryUUID, uuid)
        XCTAssertEqual(frame.binaryName, "App")
        XCTAssertEqual(frame.sampleCount, 3)
        let child = try XCTUnwrap(frame.subFrames?.first)
        XCTAssertEqual(child.address, 8_192)
        XCTAssertEqual(child.sampleCount, 2)
    }

    func testToDebugMeta_whenRootHasNoUUID_shouldPreserveChildImage() throws {
        // -- Arrange --
        let uuid = UUID()
        let child = SentryMXFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100, subFrames: nil, sampleCount: 1)
        let root = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 8_192, subFrames: [child], sampleCount: 1)

        // -- Act --
        let images = root.toDebugMeta()

        // -- Assert --
        XCTAssertEqual(images.count, 1)
        let image = try XCTUnwrap(images.first)
        XCTAssertEqual(image.type, "macho")
        XCTAssertEqual(image.debugID, uuid.uuidString)
        XCTAssertEqual(image.codeFile, "App")
        XCTAssertEqual(image.imageAddress, "0x0000000000001000")
    }

    func testToDebugMeta_whenOffsetInvalid_shouldOmitImageAddress() throws {
        // -- Arrange --
        for offset in [-1, 4_096, 4_097] {
            let frame = SentryMXFrame(binaryUUID: UUID(), offsetIntoBinaryTextSegment: offset, binaryName: "App", address: 4_096, subFrames: nil, sampleCount: nil)

            // -- Act --
            let image = try XCTUnwrap(frame.toDebugMeta().first)

            // -- Assert --
            XCTAssertNil(image.imageAddress)
        }
    }

    func testToSamples_whenSampleCountMissing_shouldReturnEmpty() {
        // -- Arrange --
        let frame = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: nil, sampleCount: nil)

        // -- Act --
        let samples = frame.toSamples()

        // -- Assert --
        XCTAssertTrue(samples.isEmpty)
    }

    func testToSentryFrameWithTreeData_whenMetadataPresent_shouldPreserveTreeData() {
        // -- Arrange --
        let frame = SentryMXFrame(binaryUUID: UUID(), offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100, subFrames: nil, sampleCount: 3)

        // -- Act --
        let result = frame.toSentryFrameWithTreeData(parentFrameIndex: 2)

        // -- Assert --
        XCTAssertEqual(result.package, "App")
        XCTAssertEqual(result.instructionAddress, "0x0000000000001004")
        XCTAssertEqual(result.imageAddress, "0x0000000000001000")
        XCTAssertEqual(result.parentIndex, 2)
        XCTAssertEqual(result.sampleCount, 3)
    }

    func testToSentryFrameWithTreeData_whenMetadataMissing_shouldOmitImageAndSampleCount() {
        // -- Arrange --
        let frame = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: nil, sampleCount: nil)

        // -- Act --
        let result = frame.toSentryFrameWithTreeData(parentFrameIndex: -1)

        // -- Assert --
        XCTAssertNil(result.package)
        XCTAssertNil(result.imageAddress)
        XCTAssertNil(result.sampleCount)
        XCTAssertEqual(result.parentIndex, -1)
        XCTAssertEqual(result.instructionAddress, "0x0000000000001000")
    }
}
#endif
