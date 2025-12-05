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
        
        XCTAssertEqual(false, callStackTree.callStackPerThread)
        XCTAssertEqual(2, callStackTree.callStacks.count)
        try assertCallStackTree(callStackTree)
        
        let debugMeta = callStackTree.toDebugMeta()
        let image = try XCTUnwrap(debugMeta.first { $0.debugID == "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967" })
        XCTAssertEqual(414_732, image.imageAddress)
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
        
//        let firstFrame = try XCTUnwrap(callStack.callStackRootFrames.first)
//        XCTAssertEqual(UUID(uuidString: "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967"), firstFrame.binaryUUID)
//        XCTAssertEqual(414_732, firstFrame.offsetIntoBinaryTextSegment)
//        XCTAssertEqual(1, firstFrame.sampleCount)
//        XCTAssertEqual("Sentry", firstFrame.binaryName)
//        XCTAssertEqual(4_312_798_220, firstFrame.address)
//        XCTAssertEqual(try XCTUnwrap(subFrameCount.first), firstFrame.subFrames?.count)
//        
//        let secondFrame = try XCTUnwrap(try XCTUnwrap(callStack.callStackRootFrames.element(at: 1)))
//        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), secondFrame.binaryUUID)
//        XCTAssertEqual(46_380, secondFrame.offsetIntoBinaryTextSegment)
//        XCTAssertEqual(1, secondFrame.sampleCount)
//        XCTAssertEqual("iOS-Swift", secondFrame.binaryName)
//        XCTAssertEqual(4_310_988_076, secondFrame.address)
//        XCTAssertEqual(try XCTUnwrap(subFrameCount.element(at: 1)), secondFrame.subFrames?.count)
//        
//        let thirdFrame = try XCTUnwrap(try XCTUnwrap(callStack.callStackRootFrames.element(at: 2)))
//        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), thirdFrame.binaryUUID)
//        XCTAssertEqual(46_370, thirdFrame.offsetIntoBinaryTextSegment)
//        XCTAssertEqual(1, thirdFrame.sampleCount)
//        XCTAssertEqual("iOS-Swift", thirdFrame.binaryName)
//        XCTAssertEqual(4_310_988_026, thirdFrame.address)
//        XCTAssertEqual(try XCTUnwrap(subFrameCount.element(at: 2)), thirdFrame.subFrames?.count ?? 0)
    }
}

#endif
