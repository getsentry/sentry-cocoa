#if os(iOS) || os(macOS)
@_spi(Private) @testable import Sentry
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
