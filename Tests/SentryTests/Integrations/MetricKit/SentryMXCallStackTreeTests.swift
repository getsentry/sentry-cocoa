#if os(iOS) || os(macOS)
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
        
        try assertCallStackTree(callStackTree, callStackCount: 2)
    }
    
    func testDecodeCallStackTree_NotPerThread() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        try assertCallStackTree(callStackTree, perThread: false, framesAmount: 14, threadAttributed: nil, subFrameCount: [2, 4, 0])
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
        XCTAssertEqual(27, callStackTree.callStacks[0].flattenedRootFrames.count)
    }
    
    func testDecodeCallStackTree_GarbagePayload() throws {
        let contents = try contentsOfResource("MetricKitCallstacks/tree-garbage")
        XCTAssertThrowsError(try SentryMXCallStackTree.from(data: contents))
    }
    
    private func assertCallStackTree(_ callStackTree: SentryMXCallStackTree, perThread: Bool = true, callStackCount: Int = 1, framesAmount: Int = 3, threadAttributed: Bool? = true, subFrameCount: [Int] = [1, 1, 0]) throws {
        
        assert(subFrameCount.count == 3, "subFrameCount must contain 3 elements.")
        
        XCTAssertNotNil(callStackTree)
        XCTAssertEqual(perThread, callStackTree.callStackPerThread)
        
        XCTAssertEqual(callStackCount, callStackTree.callStacks.count)
        
        let callStack = try XCTUnwrap(callStackTree.callStacks.first)
        XCTAssertEqual(threadAttributed, callStack.threadAttributed)
        
        XCTAssertEqual(framesAmount, callStack.flattenedRootFrames.count)
        
        let firstFrame = try XCTUnwrap(callStack.flattenedRootFrames[0])
        XCTAssertEqual(UUID(uuidString: "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967"), firstFrame.binaryUUID)
        XCTAssertEqual(414_732, firstFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, firstFrame.sampleCount)
        XCTAssertEqual("Sentry", firstFrame.binaryName)
        XCTAssertEqual(4_312_798_220, firstFrame.address)
        XCTAssertEqual(subFrameCount[0], firstFrame.subFrames?.count)
        
        let secondFrame = try XCTUnwrap(callStack.flattenedRootFrames[1])
        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), secondFrame.binaryUUID)
        XCTAssertEqual(46_380, secondFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, secondFrame.sampleCount)
        XCTAssertEqual("iOS-Swift", secondFrame.binaryName)
        XCTAssertEqual(4_310_988_076, secondFrame.address)
        XCTAssertEqual(subFrameCount[1], secondFrame.subFrames?.count)
        
        let thirdFrame = try XCTUnwrap(callStack.flattenedRootFrames[2])
        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), thirdFrame.binaryUUID)
        XCTAssertEqual(46_370, thirdFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, thirdFrame.sampleCount)
        XCTAssertEqual("iOS-Swift", thirdFrame.binaryName)
        XCTAssertEqual(4_310_988_026, thirdFrame.address)
        XCTAssertEqual(subFrameCount[2], thirdFrame.subFrames?.count ?? 0)
        
        XCTAssertEqual(try XCTUnwrap(firstFrame.subFrames?[0]), secondFrame)
    }
}

#endif
