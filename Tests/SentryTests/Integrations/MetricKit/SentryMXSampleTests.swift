#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

final class SentryMXSampleTests: XCTestCase {
    func testToSamples_whenParentHasOwnSamples_shouldPreserveCountsAndFrameOrder() {
        // -- Arrange --
        let uuid = UUID()
        let child = SentryMXFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 8, binaryName: "Child", address: 8_200, subFrames: nil, sampleCount: 2)
        let root = SentryMXFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "Root", address: 4_100, subFrames: [child], sampleCount: 5)
        let rootFrame = SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 4, binaryName: "Root", address: 4_100)
        let childFrame = SentryMXSampleFrame(binaryUUID: uuid, offsetIntoBinaryTextSegment: 8, binaryName: "Child", address: 8_200)

        // -- Act --
        let samples: [SentryMXSample] = root.toSamples()

        // -- Assert --
        XCTAssertEqual(samples.map(\.count), [2, 3])
        XCTAssertEqual(samples.map(\.frames), [[rootFrame, childFrame], [rootFrame]])
    }

    func testToSamples_whenChildrenAccountForAllSamples_shouldOmitParentOnlySample() {
        // -- Arrange --
        let child = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 8_192, subFrames: nil, sampleCount: 2)
        let root = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: [child], sampleCount: 2)

        // -- Act --
        let samples: [SentryMXSample] = root.toSamples()

        // -- Assert --
        XCTAssertEqual(samples.map(\.count), [2])
        XCTAssertEqual(samples.map { $0.frames.map(\.address) }, [[4_096, 8_192]])
    }
}
#endif
