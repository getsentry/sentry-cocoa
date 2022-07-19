import XCTest

class NSMutableDictionarySentryTests: XCTestCase {

    func testEmptyDictionary() {
        let empty = NSMutableDictionary()
        
        empty.mergeEntries(from: [String: String]())
        
        XCTAssertEqual(empty, NSMutableDictionary())
    }
    
    func testEmptyDict_AddsDict() {
        let dict = NSMutableDictionary()
        dict.mergeEntries(from: [0: [1: 1]])
        
        XCTAssertEqual([0: [1: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoEntries_ExistingGetsMerged() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0], 1: [0: 0]])
        dict.mergeEntries(from: [0: [1: 1]])
        
        XCTAssertEqual([0: [0: 0, 1: 1], 1: [0: 0]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoEntries_SameGetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0]])
        dict.mergeEntries(from: [0: [0: 1]])
        
        XCTAssertEqual([0: [0: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoLevelsNested_ExistingGetsMerged() {
        let dict = NSMutableDictionary(dictionary: [0: [0: [0: 0]]])
        dict.mergeEntries(from: [0: [0: [1: 1]]])
        
        XCTAssertEqual([0: [0: [0: 0, 1: 1]]], dict as? [Int: [Int: [Int: Int]]])
    }
    
    func testExistingNotADict_NewIsADict_GetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: 0])
        dict.mergeEntries(from: [0: [1: 1]])
        
        XCTAssertEqual([0: [1: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testExistingIsADict_NewIsNotADict_GetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0]])
        dict.mergeEntries(from: [0: 1])
        
        XCTAssertEqual([0: 1], dict as? [Int: Int])
    }
}
