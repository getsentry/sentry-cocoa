import XCTest

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
final class CallStackTreeTests: XCTestCase {
    
    func testDecodeSimpleCallStackTree() throws {
        let payload = try contentsOfResource(resource: "metric-kit-callstack-tree-simple")

        let callStackTree = try CallStackTree.from(data: payload)
        
        XCTAssertNotNil(callStackTree)
        XCTAssertTrue(callStackTree.callStackPerThread)
        
        XCTAssertEqual(1, callStackTree.callStacks.count)
        
        let callStack = try XCTUnwrap(callStackTree.callStacks.first)
        XCTAssertTrue(callStack.threadAttributed ?? false)
        
        XCTAssertEqual(2, callStack.rootFrames.count)
        
        let firstFrame = try XCTUnwrap(callStack.rootFrames[0])
        XCTAssertEqual(UUID(uuidString: "9E8D8DE6-EEC1-3199-8720-9ED68EE3F967"), firstFrame.binaryUUID)
        XCTAssertEqual(414_732, firstFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, firstFrame.sampleCount)
        XCTAssertEqual("Sentry", firstFrame.binaryName)
        XCTAssertEqual(4_312_798_220, firstFrame.address)
        XCTAssertEqual(1, firstFrame.subFrames?.count)
        
        let secondFrame = try XCTUnwrap(callStack.rootFrames[1])
        XCTAssertEqual(UUID(uuidString: "CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF"), secondFrame.binaryUUID)
        XCTAssertEqual(46_380, secondFrame.offsetIntoBinaryTextSegment)
        XCTAssertEqual(1, secondFrame.sampleCount)
        XCTAssertEqual("iOS-Swift", secondFrame.binaryName)
        XCTAssertEqual(4_310_988_076, secondFrame.address)
        XCTAssertNil(secondFrame.subFrames)
        
        XCTAssertEqual(try XCTUnwrap(firstFrame.subFrames?[0]), secondFrame)
    }

    private func contentsOfResource(resource: String, ofType: String = "json") throws -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: "Resources/\(resource)", ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: path ?? ""))
    }

}
