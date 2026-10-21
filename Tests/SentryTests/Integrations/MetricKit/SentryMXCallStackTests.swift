#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

final class SentryMXCallStackTests: XCTestCase {
    func testDecode_whenThreadAttributedMissing_shouldDecodeRootFrames() throws {
        // -- Arrange --
        let data = Data(#"{"callStackRootFrames":[{"address":4096,"offsetIntoBinaryTextSegment":0}]}"#.utf8)

        // -- Act --
        let callStack = try JSONDecoder().decode(SentryMXCallStack.self, from: data)

        // -- Assert --
        XCTAssertNil(callStack.threadAttributed)
        XCTAssertEqual(callStack.callStackRootFrames.map(\.address), [4_096])
    }

    func testDecode_whenThreadAttributedPresent_shouldPreserveValue() throws {
        // -- Arrange --
        for attributed in [true, false] {
            let data = Data("""
            {"threadAttributed":\(attributed),"callStackRootFrames":[]}
            """.utf8)

            // -- Act --
            let callStack = try JSONDecoder().decode(SentryMXCallStack.self, from: data)

            // -- Assert --
            XCTAssertEqual(callStack.threadAttributed, attributed)
            XCTAssertTrue(callStack.callStackRootFrames.isEmpty)
        }
    }

    func testToDebugMeta_whenMultipleRoots_shouldIncludeNestedImagesInOrder() throws {
        // -- Arrange --
        let firstID = UUID()
        let secondID = UUID()
        let child = SentryMXFrame(binaryUUID: secondID, offsetIntoBinaryTextSegment: 4, binaryName: "Child", address: 8_196, subFrames: nil, sampleCount: 1)
        let root = SentryMXFrame(binaryUUID: firstID, offsetIntoBinaryTextSegment: 8, binaryName: "Root", address: 4_104, subFrames: [child], sampleCount: 1)
        let callStack = SentryMXCallStack(threadAttributed: true, callStackRootFrames: [root, child])

        // -- Act --
        let images = callStack.toDebugMeta()

        // -- Assert --
        XCTAssertEqual(images.map(\.debugID), [firstID.uuidString, secondID.uuidString, secondID.uuidString])
        XCTAssertEqual(images.map(\.imageAddress), ["0x0000000000001000", "0x0000000000002000", "0x0000000000002000"])
    }
}
#endif
