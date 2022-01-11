import XCTest

class SentryByteCountFormatterTests: XCTestCase {

    func testBytesDescription(){
        assertDescription(baseValue: 1, unitName: "bytes")
    }
    
    func testKBDescription() {
        assertDescription(baseValue: 1024, unitName: "KB")
    }
    
    func testMBDescription(){
        assertDescription(baseValue: 1024 * 1024, unitName: "MB")
    }
    
    func testGBDescription(){
        assertDescription(baseValue: 1024 * 1024 * 1024, unitName: "GB")
    }
    
    func testTBDescription(){
        let baseValue : UInt = 1024 * 1024 * 1024 * 1024;
        assertDescription(baseValue: baseValue, unitName: "TB")
        XCTAssertEqual("1,024 TB", SentryByteCountFormatter.bytesCountDescription(baseValue * 1024))
    }
    
    func assertDescription(baseValue: UInt, unitName : String) {
        XCTAssertEqual("1 \(unitName)", SentryByteCountFormatter.bytesCountDescription(baseValue))
        XCTAssertEqual("512 \(unitName)", SentryByteCountFormatter.bytesCountDescription(baseValue * 512))
        XCTAssertEqual("1,023 \(unitName)", SentryByteCountFormatter.bytesCountDescription(baseValue * 1024 - 1))
    }
    
}
