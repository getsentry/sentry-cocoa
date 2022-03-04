import XCTest
import CoreData


class SentryCoreDataTrackerTests: XCTestCase {

    @objc(TestEntity)
    public class TestEntity: NSManagedObject {
        var field1: String?
        var field2: Int?
    }
    
    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        func getSut() -> SentryCoreDataTracker {
            return SentryCoreDataTracker()
        }
        
        func testEntity() -> TestEntity {
            let entityDescription = NSEntityDescription()
            entityDescription.name = "TestEntity"
            return TestEntity(entity: entityDescription, insertInto: context)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testFetchRequest() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity'")
    }
    
    func test_FetchRequest_WithPredicate() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@ and field2 = %@", argumentArray: ["First Argument", 2])
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity' WHERE field1 == \"First Argument\" AND field2 == 2")
    }
    
    func test_FetchRequest_WithSortAscending() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: true)]
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity' SORT BY field1")
    }
    
    func test_FetchRequest_WithSortDescending() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity' SORT BY field1 DESCENDING")
    }
    
    func test_FetchRequest_WithSortTwoFields() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false), NSSortDescriptor(key: "field2", ascending: true)]
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity' SORT BY field1 DESCENDING, field2")
    }
    
    func test_FetchRequest_WithPredicateAndSort() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@", argumentArray: ["First Argument"])
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        assertRequest(fetch, expectedDescription: "FETCH 'TestEntity' WHERE field1 == \"First Argument\" SORT BY field1 DESCENDING")
    }
    
    func assertRequest(_ fetch : NSFetchRequest<TestEntity>, expectedDescription : String) {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        let someEntity = fixture.testEntity()
        
        let result = try?  sut.fetchManagedObjectContext(context, request: fetch) { request, error in
            return [someEntity]
        }
      
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].context.operation, "db.query")
        XCTAssertEqual(transaction.children[0].context.spanDescription, expectedDescription)
        XCTAssertEqual(transaction.children[0].data!["result_amount"] as? Int, 1)
    }
    
    
    private func startTransaction() -> SentryTracer {
        return SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as! SentryTracer
    }
    
}
