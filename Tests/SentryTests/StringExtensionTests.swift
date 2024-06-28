import Foundation
@testable import Sentry
import XCTest

class StringExtensionTests: XCTestCase {
    
    func testSingleCharacterSubscript() {
        let testString = "Hello, World!"
        XCTAssertEqual(testString[0], "H")
        XCTAssertEqual(testString[7], "W")
        XCTAssertEqual(testString[12], "!")
    }
    
    func testRangeOfCharactersSubscript() {
        let testString = "Hello, World!"
        XCTAssertEqual(testString[1..<5], "ello")
        XCTAssertEqual(testString[7...11], "World")
        XCTAssertEqual(testString[3...3], "l")
        XCTAssertEqual(testString[1...5], "ello,")
        XCTAssertEqual(testString[7...11], "World")
        XCTAssertEqual(testString[0...0], "H")
    }
    
    func testPartialRangeThroughSubscript() {
        let testString = "Hello, World!"
        XCTAssertEqual(testString[...5], "Hello,")
        XCTAssertEqual(testString[...4], "Hello")
        XCTAssertEqual(testString[...0], "H")
    }
    
    func testPartialRangeFromSubscript() {
        let testString = "Hello, World!"
        XCTAssertEqual(testString[7...], "World!")
        XCTAssertEqual(testString[0...], "Hello, World!")
        XCTAssertEqual(testString[5...], ", World!")
    }
    
    func testPartialRangeUpToSubscript() {
        let testString = "Hello, World!"
        XCTAssertEqual(testString[..<5], "Hello")
        XCTAssertEqual(testString[..<4], "Hell")
        XCTAssertEqual(testString[..<0], "")
    }
}
