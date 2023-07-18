import CoreData
import SentryTestUtils
import XCTest

class SentryCoreDataTrackerTests: XCTestCase {
    
    private class Fixture {
        let context = TestNSManagedObjectContext()
        let threadInspector = TestThreadInspector.instance
        let imageProvider = TestDebugImageProvider()
        
        func getSut() -> SentryCoreDataTracker {
            imageProvider.debugImages = [TestData.debugImage]
            SentryDependencyContainer.sharedInstance().debugImageProvider = imageProvider

            threadInspector.allThreads = [TestData.thread2]
            let processInfoWrapper = TestSentryNSProcessInfoWrapper()
            processInfoWrapper.overrides.processDirectoryPath = "sentrytest"

            return SentryCoreDataTracker(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)
        }

        func testEntity() -> TestEntity {
            let entityDescription = NSEntityDescription()
            entityDescription.name = "TestEntity"
            return TestEntity(entity: entityDescription, insertInto: context)
        }

        func secondTestEntity() -> SecondTestEntity {
            let entityDescription = NSEntityDescription()
            entityDescription.name = "SecondTestEntity"
            return SecondTestEntity(entity: entityDescription, insertInto: context)
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
        XCTAssertEqual(SENTRY_COREDATA_FETCH_OPERATION, "db.sql.query")
        XCTAssertEqual(SENTRY_COREDATA_SAVE_OPERATION, "db.sql.transaction")
    }
    
    func testFetchRequest() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity'")
    }

    func testFetchRequestBackgroundThread() {
        let expect = expectation(description: "Operation in background thread")
        DispatchQueue.global(qos: .default).async {
            let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
            self.assertRequest(fetch, expectedDescription: "SELECT 'TestEntity'", mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1.0)
    }
    
    func test_FetchRequest_WithPredicate() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@ and field2 = %@", argumentArray: ["First Argument", 2])
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' WHERE field1 == %@ AND field2 == %@")
    }
    
    func test_FetchRequest_WithSortAscending() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: true)]
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1")
    }
    
    func test_FetchRequest_WithSortDescending() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1 DESCENDING")
    }
    
    func test_FetchRequest_WithSortTwoFields() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false), NSSortDescriptor(key: "field2", ascending: true)]
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1 DESCENDING, field2")
    }
    
    func test_FetchRequest_WithPredicateAndSort() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@", argumentArray: ["First Argument"])
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' WHERE field1 == %@ SORT BY field1 DESCENDING")
    }
    
    func test_Save_1Insert_1Entity() {
        fixture.context.inserted = [fixture.testEntity()]
        assertSave("INSERTED 1 'TestEntity'")
    }

    func testSaveBackgroundThread() {
        let expect = expectation(description: "Operation in background thread")
        DispatchQueue.global(qos: .default).async {
            self.fixture.context.inserted = [self.fixture.testEntity()]
            self.assertSave("INSERTED 1 'TestEntity'", mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1.0)
    }
    
    func test_Save_2Insert_1Entity() {
        fixture.context.inserted = [fixture.testEntity(), fixture.testEntity()]
        assertSave("INSERTED 2 'TestEntity'")
    }
    
    func test_Save_2Insert_2Entity() {
        fixture.context.inserted = [fixture.testEntity(), fixture.secondTestEntity()]
        assertSave("INSERTED 2 items")
    }
    
    func test_Save_1Update_1Entity() {
        fixture.context.updated = [fixture.testEntity()]
        assertSave("UPDATED 1 'TestEntity'")
    }
    
    func test_Save_2Update_1Entity() {
        fixture.context.updated = [fixture.testEntity(), fixture.testEntity()]
        assertSave("UPDATED 2 'TestEntity'")
    }
    
    func test_Save_2Update_2Entity() {
        fixture.context.updated = [fixture.testEntity(), fixture.secondTestEntity()]
        assertSave("UPDATED 2 items")
    }
    
    func test_Save_1Delete_1Entity() {
        fixture.context.deleted = [fixture.testEntity()]
        assertSave("DELETED 1 'TestEntity'")
    }
    
    func test_Save_2Delete_1Entity() {
        fixture.context.deleted = [fixture.testEntity(), fixture.testEntity()]
        assertSave("DELETED 2 'TestEntity'")
    }
    
    func test_Save_2Delete_2Entity() {
        fixture.context.deleted = [fixture.testEntity(), fixture.secondTestEntity()]
        assertSave("DELETED 2 items")
    }
    
    func test_Save_Insert_Update_Delete_1Entity() {
        fixture.context.inserted = [fixture.testEntity()]
        fixture.context.updated = [fixture.testEntity()]
        fixture.context.deleted = [fixture.testEntity()]
        assertSave("INSERTED 1 'TestEntity', UPDATED 1 'TestEntity', DELETED 1 'TestEntity'")
    }
    
    func test_Save_Insert_Update_Delete_2Entity() {
        fixture.context.inserted = [fixture.testEntity(), fixture.secondTestEntity()]
        fixture.context.updated = [fixture.testEntity(), fixture.secondTestEntity()]
        fixture.context.deleted = [fixture.testEntity(), fixture.secondTestEntity()]
        assertSave("INSERTED 2 items, UPDATED 2 items, DELETED 2 items")
    }
    
    func test_Operation_InData() {
        fixture.context.inserted = [fixture.testEntity(), fixture.testEntity(), fixture.secondTestEntity()]
        fixture.context.updated = [fixture.testEntity(), fixture.secondTestEntity(), fixture.secondTestEntity()]
        fixture.context.deleted = [fixture.testEntity(), fixture.testEntity(), fixture.secondTestEntity(), fixture.secondTestEntity(), fixture.secondTestEntity()]
        
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        
        XCTAssertNoThrow(try sut.managedObjectContext(fixture.context) { _ in
            return true
        })
        
        XCTAssertEqual(transaction.children.count, 1)
        
        guard let operations = transaction.children[0].data["operations"] as? [String: Any?] else {
            XCTFail("Transaction has no `operations` extra")
            return
        }
        
        XCTAssertEqual(operations.count, 3)
        
        guard let inserted = operations["INSERTED"] as? [String: Any] else {
            XCTFail("Operations has no `INSERTED` data")
            return
        }
        
        guard let updated = operations["UPDATED"] as? [String: Any] else {
            XCTFail("Operations has no `UPDATED` data")
            return
        }
        
        guard let deleted = operations["DELETED"] as? [String: Any] else {
            XCTFail("Operations has no `DELETED` data")
            return
        }
        
        XCTAssertNotNil(inserted["TestEntity"])
        XCTAssertNotNil(inserted["SecondTestEntity"])
        XCTAssertNotNil(deleted["TestEntity"])
        XCTAssertNotNil(deleted["SecondTestEntity"])
        XCTAssertNotNil(updated["TestEntity"])
        XCTAssertNotNil(updated["SecondTestEntity"])
        
        XCTAssertEqual(inserted["TestEntity"] as? Int, 2)
        XCTAssertEqual(inserted["SecondTestEntity"] as? Int, 1)
        XCTAssertEqual(deleted["TestEntity"] as? Int, 2)
        XCTAssertEqual(deleted["SecondTestEntity"] as? Int, 3)
        XCTAssertEqual(updated["TestEntity"] as? Int, 1)
        XCTAssertEqual(updated["SecondTestEntity"] as? Int, 2)
    }
    
    func test_Request_with_Error() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        let _ = try?  sut.fetchManagedObjectContext(context, request: fetch) { _, _ in
            return nil
        }
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].status, .internalError)
    }
    
    func test_Request_with_Error_is_nil() {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        XCTAssertNoThrow(try sut.fetchManagedObjectContext(context, request: fetch, isErrorNil: true) { _, _ in
            return nil
        })
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].status, .internalError)
    }
    
    func test_save_with_Error() {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        fixture.context.inserted = [fixture.testEntity()]
        XCTAssertThrowsError(try sut.managedObjectContext(fixture.context) { _ in
            return false
        })
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].status, .internalError)
    }
    
    func test_save_with_error_is_nil() {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        fixture.context.inserted = [fixture.testEntity()]
        
        sut.saveManagedObjectContext(withNilError: fixture.context) { _ in
            return false
        }
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].status, .internalError)
    }
    
    func test_Save_NoChanges() {
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        
        XCTAssertNoThrow(try sut.managedObjectContext(fixture.context) { _ in
            return true
        })
        
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func assertSave(_ expectedDescription: String, mainThread: Bool = true) {
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        
        XCTAssertNoThrow(try sut.managedObjectContext(fixture.context) { _ in
            return true
        })

        guard let dbSpan = try? XCTUnwrap(transaction.children.first) else {
            XCTFail("Span for DB operation don't exist.")
            return
        }

        XCTAssertEqual(dbSpan.operation, SENTRY_COREDATA_SAVE_OPERATION)
        XCTAssertEqual(dbSpan.spanDescription, expectedDescription)
        XCTAssertEqual(dbSpan.data["blocked_main_thread"] as? Bool ?? false, mainThread)

        if mainThread {
            guard let frames = (dbSpan as? SentrySpan)?.frames else {
                XCTFail("File IO Span in the main thread has no frames")
                return
            }
            XCTAssertEqual(frames.first, TestData.mainFrame)
            XCTAssertEqual(frames.last, TestData.testFrame)
        }
    }
    
    func assertRequest(_ fetch: NSFetchRequest<TestEntity>, expectedDescription: String, mainThread: Bool = true) {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        let someEntity = fixture.testEntity()
        
        let result = try?  sut.fetchManagedObjectContext(context, request: fetch) { _, _ in
            return [someEntity]
        }

        guard let dbSpan = try? XCTUnwrap(transaction.children.first) else {
            XCTFail("Span for DB operation don't exist.")
            return
        }

        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(dbSpan.operation, SENTRY_COREDATA_FETCH_OPERATION)
        XCTAssertEqual(dbSpan.origin, "auto.db.core_data")
        XCTAssertEqual(dbSpan.spanDescription, expectedDescription)
        XCTAssertEqual(dbSpan.data["read_count"] as? Int, 1)
        XCTAssertEqual(dbSpan.data["blocked_main_thread"] as? Bool ?? false, mainThread)

        if mainThread {
            guard let frames = (dbSpan as? SentrySpan)?.frames else {
                XCTFail("File IO Span in the main thread has no frames")
                return
            }
            XCTAssertEqual(frames.first, TestData.mainFrame)
            XCTAssertEqual(frames.last, TestData.testFrame)
        } else {
            XCTAssertNil((dbSpan as? SentrySpan)?.frames)
        }
    }
    
    private func startTransaction() -> SentryTracer {
        return SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as! SentryTracer
    }
    
}

class TestNSManagedObjectContext: NSManagedObjectContext {
    
    var inserted: Set<NSManagedObject>?
    var updated: Set<NSManagedObject>?
    var deleted: Set<NSManagedObject>?
    
    override var insertedObjects: Set<NSManagedObject> {
        inserted ?? []
    }
    
    override var updatedObjects: Set<NSManagedObject> {
        updated ?? []
    }
    
    override var deletedObjects: Set<NSManagedObject> {
        deleted ?? []
    }
    
    init() {
        super.init(concurrencyType: .mainQueueConcurrencyType)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var hasChanges: Bool {
        return  ((inserted?.count ?? 0) > 0) ||
        ((deleted?.count ?? 0) > 0) ||
        ((updated?.count ?? 0) > 0)
    }
}
