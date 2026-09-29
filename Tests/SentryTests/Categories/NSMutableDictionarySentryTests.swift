import XCTest

class NSMutableDictionarySentryTests: XCTestCase {

    func testEmptyDictionary() {
        let empty = NSMutableDictionary()
        SentryDictionary.mergeEntries(from: [String: String](), into: empty)
        XCTAssertEqual(empty, NSMutableDictionary())
    }
    
    func testEmptyDict_AddsDict() {
        let dict = NSMutableDictionary()
        SentryDictionary.mergeEntries(from: [0: [1: 1]], into: dict)
        
        XCTAssertEqual([0: [1: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoEntries_ExistingGetsMerged() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0], 1: [0: 0]])
        SentryDictionary.mergeEntries(from: [0: [1: 1]], into: dict)
        
        XCTAssertEqual([0: [0: 0, 1: 1], 1: [0: 0]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoEntries_SameGetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0]])
        SentryDictionary.mergeEntries(from: [0: [0: 1]], into: dict)
        
        XCTAssertEqual([0: [0: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testTwoLevelsNested_ExistingGetsMerged() {
        let dict = NSMutableDictionary(dictionary: [0: [0: [0: 0]]])
        SentryDictionary.mergeEntries(from: [0: [0: [1: 1]]], into: dict)
        
        XCTAssertEqual([0: [0: [0: 0, 1: 1]]], dict as? [Int: [Int: [Int: Int]]])
    }
    
    func testExistingNotADict_NewIsADict_GetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: 0])
        SentryDictionary.mergeEntries(from: [0: [1: 1]], into: dict)
        
        XCTAssertEqual([0: [1: 1]], dict as? [Int: [Int: Int]])
    }
    
    func testExistingIsADict_NewIsNotADict_GetsOverwritten() {
        let dict = NSMutableDictionary(dictionary: [0: [0: 0]])
        SentryDictionary.mergeEntries(from: [0: 1], into: dict)
        
        XCTAssertEqual([0: 1], dict as? [Int: Int])
    }
    
    func testSetBool_Nil_DoesNotSetValue() {
        let dict = NSMutableDictionary()
        SentryDictionary.setBoolValue(nil, forKey: "key", into: dict)
        XCTAssertEqual(0, dict.count)
    }
    
    func testSetBool_True_SetsTrue() {
        let dict = NSMutableDictionary()
        
        SentryDictionary.setBoolValue(true, forKey: "key", into: dict)
        
        XCTAssertTrue(dict["key"] as? Bool ?? false)
    }
    
    func testSetBool_False_SetsFalse() {
        let dict = NSMutableDictionary()
        
        SentryDictionary.setBoolValue(false, forKey: "key", into: dict)
        
        XCTAssertFalse(dict["key"] as? Bool ?? true)
        XCTAssertEqual(0, dict["key"] as? NSNumber)
    }
    
    func testSetBool_NonZero_SetsTrue() {
        let dict = NSMutableDictionary()
        
        SentryDictionary.setBoolValue(1, forKey: "key1", into: dict)
        SentryDictionary.setBoolValue(-1, forKey: "key-1", into: dict)
        
        XCTAssertTrue(dict["key1"] as? Bool ?? false)
        XCTAssertEqual(1, dict["key1"] as? NSNumber)
        
        XCTAssertTrue(dict["key-1"] as? Bool ?? false)
        XCTAssertEqual(1, dict["key-1"] as? NSNumber)
    }
}
