import CoreData
import XCTest

class SentryCoreDataTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let options: Options
        let coreDataStack = TestCoreDataStack()
        
        init() {
            options = Options()
            options.enableCoreDataTracking = true
            options.tracesSampleRate = 1
        }
        
        func getSut() -> SentryCoreDataTrackingIntegration {
            return SentryCoreDataTrackingIntegration()
        }
        
        func testEntity() -> TestEntity {
            let entityDescription = NSEntityDescription()
            entityDescription.name = "TestEntity"
            return TestEntity(entity: entityDescription, insertInto: nil)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.coreDataStack.reset()
        clearTestState()
    }
    
    func test_InstallAndUninstall() {
        let sut = fixture.getSut()
        
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.install(with: fixture.options)
        XCTAssertNotNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.uninstall()
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
    }
    
    func test_Install_swizzlingDisabled() {
        test_DontInstall { $0.enableSwizzling = false }
    }
    
    func test_Install_autoPerformanceDisabled() {
        test_DontInstall { $0.enableAutoPerformanceTracking = false }
    }
    
    func test_Install_coreDataTrackingDisabled() {
        test_DontInstall { $0.enableCoreDataTracking = false }
    }
    
    func test_Fetch() {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = startTransaction()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 1)
    }
    
    func test_Save() {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        try? stack.managedObjectContext.save()
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(transaction.children[0].context.operation, "db.transaction")
    }
    
    func test_Save_noChanges() {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = startTransaction()
        
        try? stack.managedObjectContext.save()
        
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func test_Fetch_StoppedSwizzling() {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = startTransaction()
        SentryCoreDataSwizzling.sharedInstance.stop()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func test_Save_StoppedSwizzling() {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        SentryCoreDataSwizzling.sharedInstance.stop()
        try? stack.managedObjectContext.save()
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    private func test_DontInstall(_ confOptions: ((Options) -> Void)) {
        let sut = fixture.getSut()
        confOptions(fixture.options)
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.install(with: fixture.options)
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
    }
    
    private func startTransaction() -> SentryTracer {
        return SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as! SentryTracer
    }
}
