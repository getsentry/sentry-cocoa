import SentryTestUtils
import XCTest

class ArrayAccessesTests: XCTestCase {
    func testElementAtIndex_emptyArrayWithNegativeIndex_returnsNil() {
        // -- Arrange --
        let array = [Int]()

        // -- Act --
        XCTAssertNil(array.element(at: -1))
    }

    func testElementAtIndex_emptyArrayWithIndexZero_returnsNil() {
        // -- Arrange --
        let array = [Int]()

        // -- Act --
        XCTAssertNil(array.element(at: 0))
    }

    func testElementAtIndex_emptyArrayWithPositiveIndex_returnsNil() {
        // -- Arrange --
        let array = [Int]()

        // -- Act --
        XCTAssertNil(array.element(at: 1))
    }

    func testElementAtIndex_negativeIndex_returnsNil() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        XCTAssertNil(array.element(at: -1))
    }

    func testElementAtIndex_indexBelowCount_returnsElement() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        XCTAssertEqual(array.element(at: 0), 1)
        XCTAssertEqual(array.element(at: 1), 2)
        XCTAssertEqual(array.element(at: 2), 3)
    }

    func testElementAtIndex_indexEqualCount_returnsNil() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        XCTAssertNil(array.element(at: array.count))
    }

    func testElementAtIndex_indexAboveCount_returnsNil() {
        // -- Arrange --
        let array = [1, 2, 3]
        
        // -- Act --
        XCTAssertNil(array.element(at: array.count + 1))
    }
    
    // MARK: - Edge Cases
    
    func testElementAtIndex_singleElementArray_returnsCorrectElement() {
        // -- Arrange --
        let array = [42]
        
        // -- Act --
        XCTAssertEqual(array.element(at: 0), 42)
        XCTAssertNil(array.element(at: 1))
        XCTAssertNil(array.element(at: -1))
    }
    
    func testElementAtIndex_veryLargeIndex_returnsNil() {
        // -- Arrange --
        let array = [1, 2, 3]
        
        // -- Act --
        XCTAssertNil(array.element(at: Int.max))
        XCTAssertNil(array.element(at: 1_000_000))
    }
    
    func testElementAtIndex_intMinIndex_returnsNil() {
        // -- Arrange --
        let array = [1, 2, 3]
        
        // -- Act --
        XCTAssertNil(array.element(at: Int.min))
    }
    
    // MARK: - Different Data Types
    
    func testElementAtIndex_stringArray_returnsCorrectElement() {
        // -- Arrange --
        let array = ["hello", "world", "test"]
        
        // -- Act --
        XCTAssertEqual(array.element(at: 0), "hello")
        XCTAssertEqual(array.element(at: 1), "world")
        XCTAssertEqual(array.element(at: 2), "test")
        XCTAssertNil(array.element(at: 3))
        XCTAssertNil(array.element(at: -1))
    }
    
    func testElementAtIndex_optionalArray_returnsCorrectElement() {
        // -- Arrange --
        let array: [String?] = ["hello", nil, "world"]
        
        // -- Act --
        XCTAssertEqual(array.element(at: 0), "hello")
        XCTAssertNil(array.element(at: 1))
        XCTAssertEqual(array.element(at: 2), "world")
        XCTAssertNil(array.element(at: 3))
        XCTAssertNil(array.element(at: -1))
    }
    
    func testElementAtIndex_customStructArray_returnsCorrectElement() {
        // -- Arrange --
        struct TestStruct: Equatable {
            let value: Int
        }
        
        let array = [TestStruct(value: 1), TestStruct(value: 2)]
        
        // -- Act --
        XCTAssertEqual(array.element(at: 0)?.value, 1)
        XCTAssertEqual(array.element(at: 1)?.value, 2)
        XCTAssertNil(array.element(at: 2))
        XCTAssertNil(array.element(at: -1))
    }
    
    // MARK: - Boundary Tests
    
    func testElementAtIndex_boundaryIndices_returnsCorrectResults() {
        // -- Arrange --
        let array = Array(0..<100) // Array with 100 elements
        
        // -- Act --
        XCTAssertEqual(array.element(at: 0), 0)
        XCTAssertEqual(array.element(at: 99), 99)
        XCTAssertNil(array.element(at: 100))
        XCTAssertNil(array.element(at: -1))
    }
}
