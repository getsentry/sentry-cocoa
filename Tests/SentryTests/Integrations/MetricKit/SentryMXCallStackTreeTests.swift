#if os(iOS) || os(macOS)
import MetricKit
import SentryPrivate
import XCTest

final class SentryMXCallStackTreeTests: XCTestCase {
    
    func testDecodeCallStackTree_Simple() throws {
        let contents = try contentsOfResource("metric-kit-callstack-tree-simple")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        try assertSimpleCallStackTree(callStackTree)
    }
    
    func testDecodeCallStackTree_UnknownFieldsPayload() throws {
        let contents = try contentsOfResource("metric-kit-callstack-tree-unknown-fields")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        try assertSimpleCallStackTree(callStackTree)
    }
    
    func testDecodeCallStackTree_RealPayload() throws {
        let contents = try contentsOfResource("metric-kit-callstack-tree-real")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        XCTAssertNotNil(callStackTree)
        
        // Only validate some properties as this only validates that we can
        // decode a real payload
        XCTAssertEqual(16, callStackTree.callStacks.count)
        XCTAssertEqual(27, callStackTree.callStacks[0].flattenedRootFrames.count)
    }
    
    func testDecodeCallStackTree_GarbagePayload() throws {
        let contents = try contentsOfResource("metric-kit-callstack-tree-garbage")
        XCTAssertThrowsError(try SentryMXCallStackTree.from(data: contents))
    }
    
    private func assertSimpleCallStackTree(_ callStackTree: SentryMXCallStackTree) throws {
        XCTAssertNotNil(callStackTree)
        XCTAssertTrue(callStackTree.callStackPerThread)
        
        XCTAssertEqual(1, callStackTree.callStacks.count)
        
        let callStack = try XCTUnwrap(callStackTree.callStacks.first)
        XCTAssertTrue(callStack.threadAttributed ?? false)
        
        XCTAssertEqual(2, callStack.flattenedRootFrames.count)
        
        let firstFrame = try XCTUnwrap(callStack.flattenedRootFrames[0])
        XCTAssertEqual(UUID(uuidString: "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967"), firstFrame.binaryUUID)
        XCTAssertEqual(414_732, firstFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, firstFrame.sampleCount)
        XCTAssertEqual("Sentry", firstFrame.binaryName)
        XCTAssertEqual(4_312_798_220, firstFrame.address)
        XCTAssertEqual(1, firstFrame.subFrames?.count)
        
        let secondFrame = try XCTUnwrap(callStack.flattenedRootFrames[1])
        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), secondFrame.binaryUUID)
        XCTAssertEqual(46_380, secondFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, secondFrame.sampleCount)
        XCTAssertEqual("iOS-Swift", secondFrame.binaryName)
        XCTAssertEqual(4_310_988_076, secondFrame.address)
        XCTAssertNil(secondFrame.subFrames)
        
        XCTAssertEqual(try XCTUnwrap(firstFrame.subFrames?[0]), secondFrame)
    }
}

#endif
