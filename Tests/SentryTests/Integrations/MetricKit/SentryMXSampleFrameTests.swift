#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

final class SentryMXSampleFrameTests: XCTestCase {
    func testToSentryFrame_whenBinaryMetadataPresent_shouldCalculateImageAddress() {
        // -- Arrange --
        let frame = SentryMXSampleFrame(binaryUUID: UUID(), offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100)

        // -- Act --
        let result = frame.toSentryFrame()

        // -- Assert --
        XCTAssertEqual(result.package, "App")
        XCTAssertEqual(result.instructionAddress, "0x0000000000001004")
        XCTAssertEqual(result.imageAddress, "0x0000000000001000")
    }

    func testToSentryFrame_whenUUIDMissing_shouldOmitImageAddress() {
        // -- Arrange --
        let frame = SentryMXSampleFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 4, binaryName: nil, address: 4_100)

        // -- Act --
        let result = frame.toSentryFrame()

        // -- Assert --
        XCTAssertNil(result.package)
        XCTAssertNil(result.imageAddress)
        XCTAssertEqual(result.instructionAddress, "0x0000000000001004")
    }

    func testToSentryFrame_whenOffsetInvalid_shouldOmitImageAddress() {
        // -- Arrange --
        for offset in [-1, 4_096, 4_097] {
            let frame = SentryMXSampleFrame(binaryUUID: UUID(), offsetIntoBinaryTextSegment: offset, binaryName: "App", address: 4_096)

            // -- Act --
            let result = frame.toSentryFrame()

            // -- Assert --
            XCTAssertNil(result.imageAddress)
        }
    }

    func testToSentryFrame_whenOffsetZero_shouldUseInstructionAddressAsImageAddress() {
        // -- Arrange --
        let frame = SentryMXSampleFrame(binaryUUID: UUID(), offsetIntoBinaryTextSegment: 0, binaryName: "App", address: 4_096)

        // -- Act --
        let result = frame.toSentryFrame()

        // -- Assert --
        XCTAssertEqual(result.imageAddress, result.instructionAddress)
    }

    func testHashable_whenMetadataDiffers_shouldKeepDistinctFrames() {
        // -- Arrange --
        let uuid = UUID()
        let frame = SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100)
        let identical = SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100)
        let variants = [
            SentryMXSampleFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 4_100),
            SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 8, binaryName: "App", address: 4_100),
            SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: nil, address: 4_100),
            SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "App", address: 8_192)
        ]

        // -- Act --
        let frames = Set([frame, identical] + variants)

        // -- Assert --
        XCTAssertEqual(frame, identical)
        XCTAssertEqual(frames.count, 5)
        for variant in variants {
            XCTAssertNotEqual(frame, variant)
        }
    }
}
#endif
