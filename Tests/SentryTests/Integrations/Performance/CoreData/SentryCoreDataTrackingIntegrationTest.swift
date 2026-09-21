@_spi(Private) import _SentryPrivate
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import CoreData
import SentryTestUtils
import XCTest

class SentryCoreDataTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let defaultOptions: Options
        let coreDataStack: TestCoreDataStack

        init(testName: String) throws {
            coreDataStack = try TestCoreDataStack(databaseFilename: "db-\(testName.hashValue).sqlite")
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

    override func setUpWithError() throws {
        super.setUp()
        fixture = try Fixture(testName: self.name)
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        try fixture.coreDataStack.reset()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    func test_InstallAndUninstall() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }

        XCTAssertTrue(SentryCoreDataTrackerProxy.shared.target != nil)
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
        var _ = try stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 1)
    }

    func test_Save() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        try stack.managedObjectContext.save()

        XCTAssertEqual(transaction.children.count, 1)
        XCTAssertEqual(try XCTUnwrap(transaction.children.first).operation, "db.sql.transaction")
    }

    func test_Save_noChanges() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        try stack.managedObjectContext.save()
        XCTAssertEqual(transaction.children.count, 0)
    }

    func test_Fetch_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let transaction = try startTransaction()
        (try getInstalledIntegration()).uninstall()
        var _ = try stack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(transaction.children.count, 0)
    }

    func test_Save_StoppedSwizzling() throws {
        SentrySDK.start(options: fixture.defaultOptions)
        let stack = fixture.coreDataStack
        let transaction = try startTransaction()
        let newEntity: TestEntity = stack.getEntity()
        newEntity.field1 = "Some Update"
        (try getInstalledIntegration()).uninstall()
        try stack.managedObjectContext.save()
        XCTAssertEqual(transaction.children.count, 0)
    }
    
    private func assert_DontInstall(_ confOptions: ((Options) -> Void), file: StaticString = #file, line: UInt = #line) {
        let options = fixture.defaultOptions
        confOptions(options)

        // Save current swizzling state
        let wasSwizzlingActive = SentryCoreDataTrackerProxy.shared.target != nil

        let sut = SentryCoreDataTrackingIntegration(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()
        )
        XCTAssertNil(sut, file: file, line: line)

        // Swizzling state should not have changed
        XCTAssertEqual(SentryCoreDataTrackerProxy.shared.target != nil, wasSwizzlingActive, file: file, line: line)
    }
    
    private func startTransaction() throws -> SentryTracer {
        return try XCTUnwrap(SentrySDK.startTransaction(name: "TestTransaction", operation: "TestTransaction", bindToScope: true) as? SentryTracer)
    }
    
    private func getInstalledIntegration() throws -> SentryCoreDataTrackingIntegration<SentryDependencyContainer> {
        return try XCTUnwrap(SentrySDKInternal.currentHub().getInstalledIntegration(SentryCoreDataTrackingIntegration<SentryDependencyContainer>.self) as? SentryCoreDataTrackingIntegration)
    }
}
