import XCTest

class SentryFrameTests: XCTestCase {

    func testSerialize() {
        let frame = TestData.frame
        
        let actual = frame.serialize()
        
        XCTAssertEqual(frame.columnNumber, actual["colno"] as? NSNumber)
        XCTAssertEqual(frame.fileName, actual["filename"] as? String)
        XCTAssertEqual(frame.function, actual["function"] as? String)
        XCTAssertEqual(frame.imageAddress, actual["image_addr"] as? String)
        XCTAssertEqual(frame.inApp, actual["in_app"] as? NSNumber)
        XCTAssertEqual(frame.instructionAddress, actual["instruction_addr"] as? String)
        XCTAssertEqual(frame.lineNumber, actual["lineno"] as? NSNumber)
        XCTAssertEqual(frame.module, actual["module"] as? String)
        XCTAssertEqual(frame.package, actual["package"] as? String)
        XCTAssertEqual(frame.platform, actual["platform"] as? String)
        XCTAssertEqual(frame.symbolAddress, actual["symbol_addr"] as? String)
    }
}
