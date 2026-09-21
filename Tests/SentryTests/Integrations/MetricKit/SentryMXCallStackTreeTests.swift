#if os(iOS) || os(macOS) || os(visionOS)
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport
 */
#if canImport(MetricKit)
import MetricKit
#endif

final class SentryMXCallStackTreeTests: XCTestCase {
    
    func testDecodeCallStackTree_PerThread() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/per-thread")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        XCTAssertEqual(true, callStackTree.callStackPerThread)
        XCTAssertEqual(2, callStackTree.callStacks.count)
        try assertCallStackTree(callStackTree)
        
        let debugMeta = callStackTree.toDebugMeta()
        let image = try XCTUnwrap(debugMeta.first { $0.debugID == "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967" })
        XCTAssertEqual(sentry_formatHexAddressUInt64Swift(4_312_798_220 - 414_732), image.imageAddress)
    }
    
    func testDecodeCallStackTree_NotPerThread() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        XCTAssertFalse(callStackTree.callStackPerThread)
        let firstSamples = callStackTree.callStacks[0].callStackRootFrames[0].toSamples()
        let secondSamples = callStackTree.callStacks[0].callStackRootFrames[1].toSamples()
        
        XCTAssertEqual(7, firstSamples.count)
        XCTAssertEqual(1, firstSamples[0].count)
        XCTAssertEqual(2, secondSamples.count)
    }
    
    func testMostCommonStack() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/per-thread-flamegraph")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        let threads = callStackTree.sentryMXBacktrace(inAppLogic: nil, handled: false)
        XCTAssertEqual(1, threads.count)
        let frames = try XCTUnwrap(threads[0].stacktrace).frames
        XCTAssertEqual(3, frames.count)
        XCTAssertEqual("0x0000000000000000", frames[0].instructionAddress)
        XCTAssertEqual("0x0000000000000001", frames[1].instructionAddress)
        XCTAssertEqual("0x0000000000000003", frames[2].instructionAddress)
    }
    
    func testInAppTrue_WhenPackageIsNil() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/per-thread-nil-package")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        let threads = callStackTree.sentryMXBacktrace(inAppLogic: nil, handled: false)
        XCTAssertEqual(1, threads.count)
        let frames = try XCTUnwrap(threads[0].stacktrace).frames
        XCTAssertEqual(1, frames.count)
        XCTAssertNil(frames[0].package)
        XCTAssertEqual(true, frames[0].inApp?.boolValue)
    }
    
    func testInAppTrue_WhenPackageIsNilFlamegraph() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/per-thread-nil-package")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        let threads = callStackTree.flattenedBacktrace(inAppLogic: nil, handled: false)
        XCTAssertEqual(1, threads.count)
        let frames = try XCTUnwrap(threads[0].stacktrace).frames
        XCTAssertEqual(1, frames.count)
        XCTAssertNil(frames[0].package)
        XCTAssertEqual(true, frames[0].inApp?.boolValue)
    }

    func testDecodeCallStackTree_UnknownFieldsPayload() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/tree-unknown-fields")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        try assertCallStackTree(callStackTree)
    }
    
    func testDecodeCallStackTree_RealPayload() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/tree-real")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        XCTAssertNotNil(callStackTree)
        
        // Only validate some properties as this only validates that we can
        // decode a real payload
        XCTAssertEqual(16, callStackTree.callStacks.count)
    }
    
    func testDecodeCallStackTree_whenHangDiagnosticHasMissingBinaryUUID_shouldDecode() throws {
        // -- Arrange --
        let contents = try contentsOfResource("MetricKitCallstacks/real-hang-1")
        let diagnostic = try XCTUnwrap(JSONSerialization.jsonObject(with: contents) as? [String: Any])
        let callStackTreeJSON = try XCTUnwrap(diagnostic["callStackTree"])
        let callStackTreeData = try JSONSerialization.data(withJSONObject: callStackTreeJSON)

        // -- Act --
        let callStackTree = try SentryMXCallStackTree.from(data: callStackTreeData)

        // -- Assert --
        XCTAssertTrue(callStackTree.callStackPerThread)
        XCTAssertEqual(callStackTree.callStacks.count, 1)

        let thread = try XCTUnwrap(callStackTree.flattenedBacktrace(inAppLogic: nil, handled: true).first)
        let frames = try XCTUnwrap(thread.stacktrace).frames
        XCTAssertEqual(frames.count, 857)
        let unknownFrame = try XCTUnwrap(frames.first { $0.instructionAddress == sentry_formatHexAddressUInt64Swift(6_998_633_120) })
        XCTAssertNil(unknownFrame.package)
        XCTAssertNil(unknownFrame.imageAddress)
        XCTAssertEqual(unknownFrame.sampleCount, 1)

        let images = callStackTree.toDebugMeta()
        XCTAssertEqual(images.count, 32)
        XCTAssertTrue(images.allSatisfy { $0.debugID != nil })
    }

    func testBacktraces_whenFramesHaveMissingBinaryUUID_shouldPreserveFramesAndKnownImages() throws {
        // -- Arrange --
        let contents = Data("""
        {
            "callStackPerThread": true,
            "callStacks": [{
                "callStackRootFrames": [{
                    "address": 4096,
                    "offsetIntoBinaryTextSegment": 0,
                    "sampleCount": 1,
                    "subFrames": [{
                        "binaryUUID": "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967",
                        "binaryName": "TestApp",
                        "address": 8196,
                        "offsetIntoBinaryTextSegment": 4,
                        "sampleCount": 1,
                        "subFrames": [{
                            "address": 12288,
                            "offsetIntoBinaryTextSegment": 0,
                            "sampleCount": 1
                        }]
                    }]
                }]
            }]
        }
        """.utf8)

        // -- Act --
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        let images = callStackTree.toDebugMeta()
        let backtrace = callStackTree.sentryMXBacktrace(inAppLogic: nil, handled: true)
        let flattenedBacktrace = callStackTree.flattenedBacktrace(inAppLogic: nil, handled: true)

        // -- Assert --
        XCTAssertEqual(images.count, 1)
        let image = try XCTUnwrap(images.first)
        XCTAssertEqual(image.debugID, "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967")
        XCTAssertEqual(image.imageAddress, "0x0000000000002000")

        for threads in [backtrace, flattenedBacktrace] {
            let thread = try XCTUnwrap(threads.first)
            let frames = try XCTUnwrap(thread.stacktrace).frames
            XCTAssertEqual(frames.map(\.instructionAddress), ["0x0000000000001000", "0x0000000000002004", "0x0000000000003000"])
            XCTAssertEqual(frames.map(\.imageAddress), [nil, "0x0000000000002000", nil])
            XCTAssertEqual(frames.map(\.package), [nil, "TestApp", nil])
        }
        let flattenedFrames = try XCTUnwrap(flattenedBacktrace.first?.stacktrace).frames
        XCTAssertEqual(flattenedFrames.map(\.parentIndex), [-1, 0, 1])
        XCTAssertEqual(flattenedFrames.map(\.sampleCount), [1, 1, 1])
    }

    func testDecodeCallStackTree_GarbagePayload() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/tree-garbage")
        XCTAssertThrowsError(try SentryMXCallStackTree.from(data: contents))
    }
    
    private func assertCallStackTree(_ callStackTree: SentryMXCallStackTree) throws {

        let callStack = try XCTUnwrap(callStackTree.callStacks.first)
        XCTAssertEqual(true, callStack.threadAttributed)
        
        for mxFrame in callStack.callStackRootFrames {
            XCTAssertEqual(1, mxFrame.toSamples().count)
            XCTAssertEqual(1, mxFrame.toSamples()[0].count)
        }
    }
}

#endif
