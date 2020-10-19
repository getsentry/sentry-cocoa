@testable import Sentry
import XCTest

class SentryCrashUUIDConversionTests: XCTestCase {

    /**
    * The test parameters are copied from real values during debugging
    * SentryCrashReportConverter.convertDebugMeta. We know that
    * SentryCrashReportConverter is working properly.
    */
    func testConvertBinaryImageUUID() {
        testWith(expected: "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322",
                 uuidAsCharArray: [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34])
        
        testWith(
            expected: "C6402B73-CE6B-3893-B8C4-FCA2DCBDFFF7",
            uuidAsCharArray: [198, 64, 43, 115, 206, 107, 56, 147, 184, 196, 252, 162, 220, 189, 255, 247]
        )
        
        testWith(
            expected: "4E852D8F-9427-382C-ACF0-6C38654710D0",
            uuidAsCharArray: [78, 133, 45, 143, 148, 39, 56, 44, 172, 240, 108, 56, 101, 71, 16, 208]
        )
        
        testWith(
            expected: "4E852D8F-9427-382C-ACF0-6C38654710D0",
            uuidAsCharArray: [78, 133, 45, 143, 148, 39, 56, 44, 172, 240, 108, 56, 101, 71, 16, 208]
        )
    }
    
    func testWith(expected: String, uuidAsCharArray: [UInt8]) {
        var dst: [Int8] = Array(repeating: Int8.random(in: 0..<50), count: 37)
        sentrycrashdl_convertBinaryImageUUID(uuidAsCharArray, &dst)
        
        XCTAssertEqual(expected.cString(using: .ascii), dst)
    }
    
    func testConvertBinaryImageUUID_EndsWithNullTerminated() {
        var dst: [Int8] = Array(repeating: Int8.random(in: 0..<50), count: 37)
        sentrycrashdl_convertBinaryImageUUID([78, 133, 45, 143, 148, 39, 56, 44, 172, 240, 108, 56, 101, 71, 16], &dst)
        
        XCTAssertEqual(0, dst.last)
    }
}
