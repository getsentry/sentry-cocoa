#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryMXHangCulpritIdentifierTests: XCTestCase {
    func testIdentify_whenLeavesVary_shouldSelectSharedCaller() throws {
        // -- Arrange --
        let tree = makeTree([frame(1, count: 100, app: false, children: [
            frame(2, count: 100, children: [frame(3, count: 50), frame(4, count: 50)])
        ])])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(stack).frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002"])
    }

    func testIdentify_whenAppPathIsLessFrequent_shouldApplyQualityBonus() throws {
        // -- Arrange --
        let tree = makeTree([
            frame(1, count: 80, app: false, children: [frame(2, count: 80, app: false)]),
            frame(3, count: 60, children: [frame(4, count: 60)])
        ])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        // System path: 80 * 2 = 160. App path: 60 * (2 + 2) = 240.
        XCTAssertEqual(try XCTUnwrap(stack).frames.map(\.instructionAddress), ["0x0000000000001003", "0x0000000000001004"])
    }

    func testIdentify_whenDuplicatePathsExist_shouldCombineWeights() throws {
        // -- Arrange --
        let tree = makeTree([
            frame(1, count: 30, children: [frame(2, count: 30)]),
            frame(3, count: 50, children: [frame(4, count: 50)]),
            frame(1, count: 30, children: [frame(2, count: 30)])
        ])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(stack).frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002"])
    }

    func testIdentify_whenScoresTie_shouldNotDependOnTreeOrder() throws {
        // -- Arrange --
        let roots = [frame(3, count: 1, children: [frame(4, count: 1)]), frame(1, count: 1, children: [frame(2, count: 1)])]
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let forward = sut.identify(in: makeTree(roots))
        let reversed = sut.identify(in: makeTree(roots.reversed()))

        // -- Assert --
        let expected = ["0x0000000000001001", "0x0000000000001002"]
        XCTAssertEqual(try XCTUnwrap(forward).frames.map(\.instructionAddress), expected)
        XCTAssertEqual(try XCTUnwrap(reversed).frames.map(\.instructionAddress), expected)
    }

    func testIdentify_whenEmptyOrOnlyOneFrame_shouldReturnNilLikeAndroid() {
        // -- Arrange --
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act & Assert --
        XCTAssertNil(sut.identify(in: makeTree([])))
        XCTAssertNil(sut.identify(in: makeTree([frame(1, count: 100)])))
        XCTAssertNil(sut.identify(in: makeTree([frame(1, count: 0, children: [frame(2, count: 0)])])))
    }

    func testIdentify_whenBinaryMetadataMissing_shouldKeepDistinctAddresses() throws {
        // -- Arrange --
        let leaf = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 8_192, subFrames: nil, sampleCount: 2)
        let root = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil, address: 4_096, subFrames: [leaf], sampleCount: 2)
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: []))

        // -- Act --
        let stack = sut.identify(in: makeTree([root]))

        // -- Assert --
        let frames = try XCTUnwrap(stack).frames
        XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001000", "0x0000000000002000"])
        XCTAssertTrue(frames.allSatisfy { $0.imageAddress == nil && $0.inApp == false })
    }

    func testIdentify_whenChildWeightsExceedParent_shouldRejectMalformedTree() {
        // -- Arrange --
        let tree = makeTree([frame(1, count: 1, children: [frame(2, count: 10)])])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        XCTAssertNil(stack)
    }

    func testIdentify_whenSingleStack_shouldPreserveFramesAndMixedQuality() throws {
        // -- Arrange --
        let tree = makeTree([frame(1, count: 1, app: false, children: [
            frame(2, count: 1, children: [frame(3, count: 1)])
        ])])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        let frames = try XCTUnwrap(stack).frames
        XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002", "0x0000000000001003"])
        XCTAssertEqual(frames.map(\.inApp), [false, true, true])
    }

    func testIdentify_whenFrameworkOnly_shouldStillReportStack() throws {
        // -- Arrange --
        let tree = makeTree([frame(1, count: 2, app: false, children: [frame(2, count: 2, app: false)])])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        let frames = try XCTUnwrap(stack).frames
        XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002"])
        XCTAssertEqual(frames.map(\.inApp), [false, false])
    }

    func testIdentify_whenFrequencyEqual_shouldPreferDeeperStack() throws {
        // -- Arrange --
        let tree = makeTree([
            frame(1, count: 1, children: [frame(2, count: 1)]),
            frame(3, count: 1, children: [frame(4, count: 1, children: [frame(5, count: 1)])])
        ])
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(stack).frames.map(\.instructionAddress), ["0x0000000000001003", "0x0000000000001004", "0x0000000000001005"])
    }

    func testIdentify_whenSampleCountsInvalid_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))
        let missingCount = SentryMXFrame(binaryUUID: nil, offsetIntoBinaryTextSegment: 0, binaryName: nil,
                                        address: 4_096, subFrames: nil, sampleCount: nil)
        let trees = [
            makeTree([frame(1, count: -1)]),
            makeTree([missingCount]),
            makeTree([frame(1, count: Int.max, children: [frame(2, count: Int.max), frame(3, count: Int.max)])])
        ]

        // -- Act & Assert --
        for tree in trees {
            XCTAssertNil(sut.identify(in: tree))
        }
    }

    func testIdentify_whenLaterStackAttributed_shouldUseFirstStackLikeLegacy() throws {
        // -- Arrange --
        let tree = SentryMXCallStackTree(callStacks: [
            SentryMXCallStack(threadAttributed: false, callStackRootFrames: [frame(1, count: 1, children: [frame(2, count: 1)])]),
            SentryMXCallStack(threadAttributed: true, callStackRootFrames: [frame(3, count: 100, children: [frame(4, count: 100)])])
        ], callStackPerThread: true)
        let sut = SentryMXHangCulpritIdentifier(inAppLogic: SentryInAppLogic(inAppIncludes: ["App"]))

        // -- Act --
        let stack = sut.identify(in: tree)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(stack).frames.map(\.instructionAddress), ["0x0000000000001001", "0x0000000000001002"])
    }

    private func makeTree(_ roots: [SentryMXFrame]) -> SentryMXCallStackTree {
        SentryMXCallStackTree(callStacks: [SentryMXCallStack(threadAttributed: false, callStackRootFrames: roots)], callStackPerThread: true)
    }

    private func frame(_ offset: Int, count: Int, app: Bool = true, children: [SentryMXFrame] = []) -> SentryMXFrame {
        SentryMXFrame(binaryUUID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"), offsetIntoBinaryTextSegment: offset,
                      binaryName: app ? "App" : "System", address: UInt64(4_096 + offset), subFrames: children, sampleCount: count)
    }
}
#endif
