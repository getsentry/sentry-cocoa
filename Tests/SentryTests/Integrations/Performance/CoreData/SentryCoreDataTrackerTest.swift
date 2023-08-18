import CoreData
import SentryTestUtils
import XCTest

class SentryCoreDataTrackerTests: XCTestCase {
    
    private class Fixture {
        let coreDataStack = TestCoreDataStack()
        lazy var context: TestNSManagedObjectContext = {
            coreDataStack.managedObjectContext
        }()
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
    
    func testFetchRequest() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity'")
    }

    func testFetchRequestBackgroundThread() {
        let expect = expectation(description: "Operation in background thread")
        DispatchQueue.global(qos: .default).async {
            let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
            try? self.assertRequest(fetch, expectedDescription: "SELECT 'TestEntity'", mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1.0)
    }
    
    func test_FetchRequest_WithPredicate() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@ and field2 = %@", argumentArray: ["First Argument", 2])
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' WHERE field1 == %@ AND field2 == %@")
    }
    
    func test_FetchRequest_WithSortAscending() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: true)]
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1")
    }
    
    func test_FetchRequest_WithSortDescending() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1 DESCENDING")
    }
    
    func test_FetchRequest_WithSortTwoFields() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false), NSSortDescriptor(key: "field2", ascending: true)]
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' SORT BY field1 DESCENDING, field2")
    }
    
    func test_FetchRequest_WithPredicateAndSort() throws {
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        fetch.predicate = NSPredicate(format: "field1 = %@", argumentArray: ["First Argument"])
        fetch.sortDescriptors = [NSSortDescriptor(key: "field1", ascending: false)]
        try assertRequest(fetch, expectedDescription: "SELECT 'TestEntity' WHERE field1 == %@ SORT BY field1 DESCENDING")
    }
    
    func test_Save_1Insert_1Entity() throws {
        fixture.context.inserted = [fixture.testEntity()]
        try assertSave("INSERTED 1 'TestEntity'")
    }

    func testSaveBackgroundThread() {
        let expect = expectation(description: "Operation in background thread")
        DispatchQueue.global(qos: .default).async {
            self.fixture.context.inserted = [self.fixture.testEntity()]
            try? self.assertSave("INSERTED 1 'TestEntity'", mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1.0)
    }
    
    func test_Save_2Insert_1Entity() throws {
        fixture.context.inserted = [fixture.testEntity(), fixture.testEntity()]
        try assertSave("INSERTED 2 'TestEntity'")
    }
    
    func test_Save_2Insert_2Entity() throws {
        fixture.context.inserted = [fixture.testEntity(), fixture.secondTestEntity()]
        try assertSave("INSERTED 2 items")
    }
    
    func test_Save_1Update_1Entity() throws {
        fixture.context.updated = [fixture.testEntity()]
        try assertSave("UPDATED 1 'TestEntity'")
    }
    
    func test_Save_2Update_1Entity() throws {
        fixture.context.updated = [fixture.testEntity(), fixture.testEntity()]
        try assertSave("UPDATED 2 'TestEntity'")
    }
    
    func test_Save_2Update_2Entity() throws {
        fixture.context.updated = [fixture.testEntity(), fixture.secondTestEntity()]
        try assertSave("UPDATED 2 items")
    }
    
    func test_Save_1Delete_1Entity() throws {
        fixture.context.deleted = [fixture.testEntity()]
        try assertSave("DELETED 1 'TestEntity'")
    }
    
    func test_Save_2Delete_1Entity() throws {
        fixture.context.deleted = [fixture.testEntity(), fixture.testEntity()]
        try assertSave("DELETED 2 'TestEntity'")
    }
    
    func test_Save_2Delete_2Entity() throws {
        fixture.context.deleted = [fixture.testEntity(), fixture.secondTestEntity()]
        try assertSave("DELETED 2 items")
    }
    
    func test_Save_Insert_Update_Delete_1Entity() throws {
        fixture.context.inserted = [fixture.testEntity()]
        fixture.context.updated = [fixture.testEntity()]
        fixture.context.deleted = [fixture.testEntity()]
        try assertSave("INSERTED 1 'TestEntity', UPDATED 1 'TestEntity', DELETED 1 'TestEntity'")
    }
    
    func test_Save_Insert_Update_Delete_2Entity() throws {
        fixture.context.inserted = [fixture.testEntity(), fixture.secondTestEntity()]
        fixture.context.updated = [fixture.testEntity(), fixture.secondTestEntity()]
        fixture.context.deleted = [fixture.testEntity(), fixture.secondTestEntity()]
        try assertSave("INSERTED 2 items, UPDATED 2 items, DELETED 2 items")
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

}

private extension SentryCoreDataTrackerTests {

    func assertSave(_ expectedDescription: String, mainThread: Bool = true) throws {
        let sut = fixture.getSut()
        
        let transaction = startTransaction()
        
        XCTAssertNoThrow(try sut.managedObjectContext(fixture.context) { _ in
            return true
        })

        let dbSpan = try XCTUnwrap(transaction.children.first)
        
        assertDataAndFrames(dbSpan: dbSpan, expectedOperation: SENTRY_COREDATA_SAVE_OPERATION, expectedDescription: expectedDescription, mainThread: mainThread)
    }
    
    func assertRequest(_ fetch: NSFetchRequest<TestEntity>, expectedDescription: String, mainThread: Bool = true) throws {
        let transaction = startTransaction()
        let sut = fixture.getSut()
        
        let context = fixture.context
        
        let someEntity = fixture.testEntity()
        
        let result = try? sut.fetchManagedObjectContext(context, request: fetch) { _, _ in
            return [someEntity]
        }

        let dbSpan = try XCTUnwrap(transaction.children.first)

        XCTAssertEqual(result?.count, 1)

        assertDataAndFrames(dbSpan: dbSpan, expectedOperation: SENTRY_COREDATA_FETCH_OPERATION, expectedDescription: expectedDescription, mainThread: mainThread)
    }

    func assertDataAndFrames(dbSpan: Span, expectedOperation: String, expectedDescription: String, mainThread: Bool) {
        XCTAssertEqual(dbSpan.operation, expectedOperation)
        XCTAssertEqual(dbSpan.spanDescription, expectedDescription)
        XCTAssertEqual(dbSpan.data["blocked_main_thread"] as? Bool ?? false, mainThread)
        XCTAssertEqual(try XCTUnwrap(dbSpan.data["db.system"] as? String), "SQLite")
        XCTAssert(try XCTUnwrap(dbSpan.data["db.name"] as? NSString).contains(TestCoreDataStack.databaseFilename))

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

//class TestCoreDataStack {
//    lazy var managedObjectModel = TestNSManagedObjectModel()
//    lazy var persistentStoreCoordinator = TestNSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
//    lazy var managedObjectContext = TestNSManagedObjectContext()
//}
//
//class TestNSManagedObjectModel: NSManagedObjectModel {
//
//}
//
//class TestNSPersistentStoreCoordinator: NSPersistentStoreCoordinator {
//    override init(managedObjectModel model: NSManagedObjectModel) {
//        super.init(managedObjectModel: model)
//        try! addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
//    }
//}
