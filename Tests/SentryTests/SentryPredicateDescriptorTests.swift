import XCTest

class SentryPredicateDescriptorTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryPredicateDescriptor {
            return SentryPredicateDescriptor()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func test_lessThanOperator() {
        let pred = NSPredicate(format: "field1 < %@", argumentArray: [0])
        assertPredicate(predicate: pred, expectedResult: "field1 < %@")
    }
    
    func test_lessThanOrEqualOperator() {
        let pred = NSPredicate(format: "field1 <= %@")
        assertPredicate(predicate: pred, expectedResult: "field1 <= %@")
    }
    
    func test_greaterThanOperator() {
        let pred = NSPredicate(format: "field1 > %@")
        assertPredicate(predicate: pred, expectedResult: "field1 > %@")
    }
    
    func test_greaterThanOrEqualOperator() {
        let pred = NSPredicate(format: "field1 >= %@")
        assertPredicate(predicate: pred, expectedResult: "field1 >= %@")
    }

    func test_equalOperator() {
        let pred = NSPredicate(format: "field1 = %@")
        assertPredicate(predicate: pred, expectedResult: "field1 == %@")
    }
    
    func test_notEqualOperator() {
        let pred = NSPredicate(format: "field1 != %@")
        assertPredicate(predicate: pred, expectedResult: "field1 != %@")
    }
    
    func test_MatchesOperator() {
        let pred = NSPredicate(format: "field1 matches %@")
        assertPredicate(predicate: pred, expectedResult: "field1 MATCHES %@")
    }
    
    func test_beginsWithOperator() {
        let pred = NSPredicate(format: "field1 beginsWith %@")
        assertPredicate(predicate: pred, expectedResult: "field1 BEGINSWITH %@")
    }
    
    func test_endsWithOperator() {
        let pred = NSPredicate(format: "field1 endsWith %@")
        assertPredicate(predicate: pred, expectedResult: "field1 ENDSWITH %@")
    }
    
    func test_inOperator() {
        let pred = NSPredicate(format: "field1 in %@")
        assertPredicate(predicate: pred, expectedResult: "field1 IN %@")
    }
    
    func test_containsOperator() {
        let pred = NSPredicate(format: "field1 contains %@")
        assertPredicate(predicate: pred, expectedResult: "field1 CONTAINS %@")
    }
    
    func test_betweenOperator() {
        let pred = NSPredicate(format: "field1 between %@")
        assertPredicate(predicate: pred, expectedResult: "field1 BETWEEN %@")
    }
    
    func test_likeOperator() {
        let pred = NSPredicate(format: "field1 like %@")
        assertPredicate(predicate: pred, expectedResult: "field1 LIKE %@")
    }
    
    func test_andCompound() {
        let pred = NSPredicate(format: "field1 = %@ and field2 = %@", "arg1", "arg2")
        assertPredicate(predicate: pred, expectedResult: "field1 == %@ AND field2 == %@")
    }
    
    func test_orCompound() {
        let pred = NSPredicate(format: "field1 = %@ or field2 = %@", "arg1", "arg2")
        assertPredicate(predicate: pred, expectedResult: "field1 == %@ OR field2 == %@")
    }
    
    func test_notCompound() {
        let pred = NSPredicate(format: "not field1 = %@")
        assertPredicate(predicate: pred, expectedResult: "NOT field1 == %@")
    }
    
    func test_AggregateExpression() {
        let pred = NSPredicate(format: "field1 in {1,2,3,4}")
        assertPredicate(predicate: pred, expectedResult: "field1 IN {%@, %@, %@, %@}")
    }
    
    func test_ternaryExpression() {
        let pred = NSPredicate(format: "ternary(field1 = %@ , 1 , 2) == 1")
        assertPredicate(predicate: pred, expectedResult: "TERNARY(field1 == %@,%@,%@) == %@")
    }
    
    func test_compoundInCompound() {
        let pred = NSPredicate(format: "field1 = 1 And field2 = 2 or field2 = 1")
        assertPredicate(predicate: pred, expectedResult: "(field1 == %@ AND field2 == %@) OR field2 == %@")
    }
    
    func test_compoundInCompound_2() {
        let pred = NSPredicate(format: "field1 = 1 And (field3 = 2 or field2 = 1)")
        assertPredicate(predicate: pred, expectedResult: "field1 == %@ AND (field3 == %@ OR field2 == %@)")
    }
    
    func test_UNKNOWN() {
        let pred = NSPredicate { _, _ in
            return false
        }
        assertPredicate(predicate: pred, expectedResult: "<UNKNOWN PREDICATE>")
    }
    
    func test_invalidCompound() {
        guard let invalidCompound = NSCompoundPredicate.LogicalType(rawValue: 6) else {
            XCTFail("Could not create invalid compound type")
            return
        }
        
        let pred = NSCompoundPredicate(type: invalidCompound, subpredicates: [NSComparisonPredicate(format: "field1 == 1"), NSComparisonPredicate(format: "field2 == 2")])
        
        assertPredicate(predicate: pred, expectedResult: "field1 == %@, field2 == %@")
    }
    
    func test_invalidComparison() {
        let pred = NSComparisonPredicate(leftExpression: NSExpression(format: "field1"), rightExpression: NSExpression(format: "1"), customSelector: #selector(compareFunction(_:_:)))
        
        assertPredicate(predicate: pred, expectedResult: "<COMPARISON NOT SUPPORTED>")
    }
    
    @objc
    func compareFunction(_ item1: AnyObject, _ item2: AnyObject) -> Bool {
        return item1 === item2
    }
    
    func assertPredicate(predicate: NSPredicate, expectedResult: String ) {
        let sut = fixture.getSut()
        XCTAssertEqual(sut.predicateDescription(predicate), expectedResult)
    }
    
}
