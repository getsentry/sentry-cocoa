import Foundation
@testable import Sentry
import XCTest
import Nimble

class StringExtensionTests : XCTestCase {
    
    func testSingleCharacterSubscript() {
        let testString = "Hello, World!"
        expect(testString[0]) == "H"
        expect(testString[7]) == "W"
        expect(testString[12]) == "!"
    }
    
    func testRangeOfCharactersSubscript() {
        let testString = "Hello, World!"
        expect(testString[1..<5]) == "ello"
        expect(testString[7...11]) == "World"
        expect(testString[3...3]) == "l"
        expect(testString[1...5]) == "ello,"
        expect(testString[7...11]) == "World"
        expect(testString[0...0]) == "H"
    }
    
    func testPartialRangeThroughSubscript() {
        let testString = "Hello, World!"
        expect(testString[...5]) == "Hello,"
        expect(testString[...4]) == "Hello"
        expect(testString[...0]) == "H"
    }
    
    func testPartialRangeFromSubscript() {
        let testString = "Hello, World!"
        expect(testString[7...]) == "World!"
        expect(testString[0...]) == "Hello, World!"
        expect(testString[5...]) == ", World!"
    }
    
    func testPartialRangeUpToSubscript() {
        let testString = "Hello, World!"
        expect(testString[..<5]) == "Hello"
        expect(testString[..<4]) == "Hell"
        expect(testString[..<0]) == ""
    }
}
