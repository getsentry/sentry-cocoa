@_spi(Private) import _SentryPrivate
import CoreData
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryCoreDataTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let defaultOptions: Options
        let coreDataStack: TestCoreDataStack

        init(testName: String) {
            coreDataStack = TestCoreDataStack(databaseFilename: "db-\(testName.hashValue).sqlite")
            let options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: SentryCoreDataTrackingIntegrationTests.self)
            options.removeAllIntegrations()
            options.enableAutoPerformanceTracing = true
            options.enableSwizzling = true
            options.enableCoreDataTracing = true
            options.tracesSampleRate = 1
            defaultOptions = options
        }

        func getSut(options: Options? = nil) throws -> SentryCoreDataTrackingIntegration<SentryDependencyContainer> {
            let container = SentryDependencyContainer.sharedInstance()

            return try XCTUnwrap(SentryCoreDataTrackingIntegration(
                with: options ?? defaultOptions,
                dependencies: container
            ))
        }
    }
    
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture(testName: self.name)
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.coreDataStack.reset()
        clearTestState()
    }
    
    func test_InstallAndUninstall() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }

        XCTAssertTrue(SentryCoreDataSwizzlingHelper.swizzlingActive())
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

    func test_Install_tracingDisabled() {
        assert_DontInstall { $0.tracesSampleRate = 0 }
    }
    
    func test_Fetch() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = try startTransaction()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 1)
    }

    func test_Save() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        try? stack.managedObjectContext.save()

        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(try XCTUnwrap(transaction.children.first).operation, "db.sql.transaction")
    }

    func test_Save_noChanges() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()

        try? stack.managedObjectContext.save()

        XCTAssertEqual(transaction.children.count, 0)
    }

    func test_Fetch_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = try startTransaction()
        SentryCoreDataSwizzling.sharedInstance.stop()
        var _ = try? stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 0)
    }

    func test_Save_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        SentryCoreDataSwizzling.sharedInstance.stop()
        try? stack.managedObjectContext.save()
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    private func assert_DontInstall(_ confOptions: ((Options) -> Void), file: StaticString = #file, line: UInt = #line) {
        let options = fixture.defaultOptions
        confOptions(options)

        // Save current swizzling state
        let wasSwizzlingActive = SentryCoreDataSwizzlingHelper.swizzlingActive()

        let sut = SentryCoreDataTrackingIntegration(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()
        )
        XCTAssertNil(sut, file: file, line: line)

        // Swizzling state should not have changed
        XCTAssertEqual(SentryCoreDataSwizzlingHelper.swizzlingActive(), wasSwizzlingActive, file: file, line: line)
    }
    
    private func startTransaction() throws -> SentryTracer {
        return try XCTUnwrap(SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as? SentryTracer)
    }
}
