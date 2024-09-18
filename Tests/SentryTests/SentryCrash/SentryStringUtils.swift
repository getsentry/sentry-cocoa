import XCTest

final class SentryStringUtils: XCTestCase {
    
    func testStrncpy_safe_BiggerBuffer() throws {
        let strn = "Hello, World!"
        let dstBufferSize = strn.count + 1
        
        let dst = UnsafeMutablePointer<CChar>.allocate(capacity: dstBufferSize)
        defer { dst.deallocate() }
        
        let n = try XCTUnwrap(strncpy_safe(dst, strn, dstBufferSize))
        let result = String(cString: n)
        
        XCTAssertEqual(result, strn)
    }
    
    func testStrncpy_safe_smallerBuffer() throws {
        let strn = "Hello, World!"
        let dstBufferSize = 6
        
        let dst = UnsafeMutablePointer<CChar>.allocate(capacity: dstBufferSize)
        defer { dst.deallocate() }
        
        let n = try XCTUnwrap(strncpy_safe(dst, strn, dstBufferSize))
        let result = String(cString: n)
        
        XCTAssertEqual(result, "Hello")
    }
    
}
