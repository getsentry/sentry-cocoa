import CoreData
import XCTest

class SentryCoreDataTrackerTests: XCTestCase {
    
    private class Fixture {
        let context = TestNSManagedObjectContext()
        
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
    
    func testConstants() {
        //Test constants to make sure we don't accidentally change it
        XCTAssertEqual(SENTRY_COREDATA_FETCH_OPERATION, "db.query")
        XCTAssertEqual(SENTRY_COREDATA_SAVE_OPERATION, "db.transaction")
        
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
    
    func test_Save() {
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        fixture.context.withChanges = true
        
        try? sut.saveManagedObjectContext(fixture.context) { _ in
            return true
        }
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].context.operation, SENTRY_COREDATA_SAVE_OPERATION)
        XCTAssertEqual(transaction.children[0].context.spanDescription, "Saving Database")
    }
    
    func test_Save_NoChanges() {
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        
        try? sut.saveManagedObjectContext(fixture.context) { _ in
            return true
        }
        
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func assertRequest(_ fetch: NSFetchRequest<TestEntity>, expectedDescription: String) {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        let someEntity = fixture.testEntity()
        
        let result = try?  sut.fetchManagedObjectContext(context, request: fetch) { _, _ in
            return [someEntity]
        }
      
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].context.operation, SENTRY_COREDATA_FETCH_OPERATION)
        XCTAssertEqual(transaction.children[0].context.spanDescription, expectedDescription)
        XCTAssertEqual(transaction.children[0].data!["result_amount"] as? Int, 1)
    }
    
    private func startTransaction() -> SentryTracer {
        return SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as! SentryTracer
    }
    
}

class TestNSManagedObjectContext: NSManagedObjectContext {
    
    var withChanges = false
    
    init() {
        super.init(concurrencyType: .mainQueueConcurrencyType)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var hasChanges: Bool {
        return withChanges
    }
    
}
