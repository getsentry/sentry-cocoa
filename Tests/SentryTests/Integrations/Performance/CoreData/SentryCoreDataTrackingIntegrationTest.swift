import CoreData
import SentryTestUtils
import XCTest

class SentryCoreDataTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let options: Options
        let coreDataStack = TestCoreDataStack()
        
        init() {
            options = Options()
            options.enableCoreDataTracing = true
            options.tracesSampleRate = 1
            options.setIntegrations([SentryCoreDataTrackingIntegration.self])
        }
        
        func getSut() -> SentryCoreDataTrackingIntegration {
            return SentryCoreDataTrackingIntegration()
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
        
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.coreDataTracker)
        sut.install(with: fixture.options)
        XCTAssertNotNil(SentryCoreDataSwizzling.sharedInstance.coreDataTracker)
        sut.uninstall()
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.coreDataTracker)
    }
    
    func test_Install_swizzlingDisabled() {
        assert_DontInstall { $0.enableSwizzling = false }
    }
    
    func test_Install_autoPerformanceDisabled() {
        assert_DontInstall { $0.enableAutoPerformanceTracing = false }
    }
    
    func test_Install_coreDataTrackingDisabled() {
        assert_DontInstall { $0.enableCoreDataTracing = false }
    }
    
    func test_Fetch() throws {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = try startTransaction()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 1)
    }
    
    func test_Save() throws {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        try? stack.managedObjectContext.save()
        
        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(try XCTUnwrap(transaction.children.first).operation, "db.sql.transaction")
    }
    
    func test_Save_noChanges() throws {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        
        try? stack.managedObjectContext.save()
        
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func test_Fetch_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = try startTransaction()
        SentryCoreDataSwizzling.sharedInstance.stop()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    func test_Save_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.options)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        SentryCoreDataSwizzling.sharedInstance.stop()
        try? stack.managedObjectContext.save()
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    private func assert_DontInstall(_ confOptions: ((Options) -> Void)) {
        let sut = fixture.getSut()
        confOptions(fixture.options)
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.coreDataTracker)
        sut.install(with: fixture.options)
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.coreDataTracker)
    }
    
    private func startTransaction() throws -> SentryTracer {
        return try XCTUnwrap(SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as? SentryTracer)
    }
}
