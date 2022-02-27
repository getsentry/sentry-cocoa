import XCTest
import CoreData


class SentryCoreDataTrackerTests: XCTestCase {

    @objc(TestEntity)
    public class TestEntity: NSManagedObject {}
    
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
    
    func testFetchRequest_CheckSpan() {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        
        let someEntity = fixture.testEntity()
        
        let result = try?  sut.fetchManagedObjectContext(context, request: fetch) { request, error in
            return [someEntity]
        }
      
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].context.operation, "db.query")
        XCTAssertEqual(transaction.children[0].context.spanDescription, "FETCH 'TestEntity'")
        XCTAssertEqual(transaction.children[0].data!["result_amount"] as? Int, 1)
    }
    
    
    private func startTransaction() -> SentryTracer {
        return SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as! SentryTracer
    }
    
}
