#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import CoreData
import Foundation
import SentryTestUtils
import XCTest

final class SentryCoreDataSwizzlingTests: XCTestCase {
    private var coreDataStack: TestCoreDataStack!
    private var mockTracker: MockCoreDataTracker!
    private var integration: SentryCoreDataTrackingIntegration<CoreDataTestDependencies>?

    override func setUpWithError() throws {
        super.setUp()
        coreDataStack = try TestCoreDataStack(databaseFilename: "db-swizzling-\(UUID().uuidString).sqlite")
        mockTracker = MockCoreDataTracker()
    }

    override func tearDownWithError() throws {
        integration?.uninstall()
        integration = nil
        XCTAssertFalse(isTrackingActive, "Swizzling should be inactive after stop called")
        try coreDataStack.reset()
        super.tearDown()
    }

    private var isTrackingActive: Bool {
        SentryCoreDataTrackerProxy.shared.target != nil
    }

    private func makeIntegration(tracker: MockCoreDataTracker) -> SentryCoreDataTrackingIntegration<CoreDataTestDependencies>? {
        let options = Options()
        options.tracesSampleRate = 1
        return SentryCoreDataTrackingIntegration(with: options, dependencies: CoreDataTestDependencies(tracker: tracker))
    }

    private func swizzle() {
        integration = makeIntegration(tracker: mockTracker)
        XCTAssertTrue(isTrackingActive, "Swizzling should be active after swizzle call")
    }

    func testFetch_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        XCTAssertEqual(mockTracker.fetchCalls.count, 0, "Should start with no fetch calls")

        // -- Act --
        _ = try coreDataStack.managedObjectContext.fetch(fetch)

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 1, "Should record one fetch call")
        XCTAssertEqual(mockTracker.fetchCalls[0].entityName, "TestEntity", "Should record correct entity name")
    }

    func testFetch_whenNotSwizzled_shouldNotCallTracker() throws {
        // -- Arrange --
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        XCTAssertEqual(mockTracker.fetchCalls.count, 0, "Should start with no fetch calls")

        // -- Act --
        _ = try coreDataStack.managedObjectContext.fetch(fetch)

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 0, "Should not record fetch call when not swizzled")
    }

    func testFetch_whenStopCalled_shouldNotCallTracker() throws {
        // -- Arrange --
        swizzle()
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        _ = try coreDataStack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(mockTracker.fetchCalls.count, 1, "Should track call when swizzled")

        // -- Act --
        integration?.uninstall()
        _ = try coreDataStack.managedObjectContext.fetch(fetch)

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 1, "Should not track new calls after stop called")
    }

    func testSave_whenSwizzled_shouldCallTracker() throws {
        // -- Arrange --
        swizzle()
        let entity: TestEntity = coreDataStack.getEntity()
        entity.field1 = "Test Update"
        XCTAssertEqual(mockTracker.saveCalls.count, 0, "Should start with no save calls")

        // -- Act --
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should record one save call")
    }

    func testSave_whenNotSwizzled_shouldNotCallTracker() throws {
        // -- Arrange --
        let entity: TestEntity = coreDataStack.getEntity()
        entity.field1 = "Test Update"
        XCTAssertEqual(mockTracker.saveCalls.count, 0, "Should start with no save calls")

        // -- Act --
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertEqual(mockTracker.saveCalls.count, 0, "Should not record save call when not swizzled")
    }

    func testSave_noChanges_whenSwizzled_shouldNotCallTracker() throws {
        // -- Arrange --
        swizzle()
        XCTAssertEqual(mockTracker.saveCalls.count, 0, "Should start with no save calls")

        // -- Act --
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        // The tracker detects unchanged contexts, not the swizzle.
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should call tracker even with no changes")
    }

    func testSave_whenStop_shouldNotCallTracker() throws {
        // -- Arrange --
        swizzle()
        let entity1: TestEntity = coreDataStack.getEntity()
        entity1.field1 = "First Update"
        try coreDataStack.managedObjectContext.save()
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should track call when swizzled")

        // -- Act --
        integration?.uninstall()
        let entity2: TestEntity = coreDataStack.getEntity()
        entity2.field1 = "Second Update"
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should not track new calls after stop called")
    }

    func testSwizzlingActive_whenSwizzled_shouldBeTrue() {
        // -- Arrange & Act --
        swizzle()

        // -- Assert --
        XCTAssertTrue(isTrackingActive, "Swizzling should be active after swizzle call")
    }

    func testSwizzlingActive_whenStopCalled_shouldBeFalse() {
        // -- Arrange --
        swizzle()
        XCTAssertTrue(isTrackingActive, "Swizzling should initially be active")

        // -- Act --
        integration?.uninstall()

        // -- Assert --
        XCTAssertFalse(isTrackingActive, "Swizzling should be inactive after stop called")
        swizzle()
    }

    func testStop_whenCalledMultipleTimes_shouldNotCrash() {
        // -- Arrange --
        swizzle()

        // -- Act & Assert --
        integration?.uninstall()
        integration?.uninstall()
        integration?.uninstall()
    }

    func testMultipleOperations_whenSwizzled_shouldRecordAllCalls() throws {
        // -- Arrange --
        swizzle()
        let fetch = NSFetchRequest<TestEntity>(entityName: "TestEntity")
        let entity: TestEntity = coreDataStack.getEntity()
        entity.field1 = "Test Data"
        XCTAssertEqual(mockTracker.fetchCalls.count, 0, "Should start with no fetch calls")
        XCTAssertEqual(mockTracker.saveCalls.count, 0, "Should start with no save calls")

        // -- Act --
        _ = try coreDataStack.managedObjectContext.fetch(fetch)
        try coreDataStack.managedObjectContext.save()
        _ = try coreDataStack.managedObjectContext.fetch(fetch)

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 2, "Should record two fetch calls")
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should record one save call")
    }

    func testInstall_whenRepeated_shouldNotStackInterceptors() throws {
        // -- Arrange --
        swizzle()
        let first = integration
        swizzle()

        // -- Act --
        _ = try coreDataStack.managedObjectContext.fetch(NSFetchRequest<TestEntity>(entityName: "TestEntity"))
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertNotNil(first)
        XCTAssertEqual(mockTracker.fetchCalls.count, 1)
        XCTAssertEqual(mockTracker.saveCalls.count, 1)
    }

    func testUninstall_whenOlderIntegrationStops_shouldKeepNewTracker() throws {
        // -- Arrange --
        swizzle()
        let first = try XCTUnwrap(integration)
        let replacement = MockCoreDataTracker()
        integration = makeIntegration(tracker: replacement)

        // -- Act --
        first.uninstall()
        _ = try coreDataStack.managedObjectContext.fetch(NSFetchRequest<TestEntity>(entityName: "TestEntity"))
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 0)
        XCTAssertEqual(mockTracker.saveCalls.count, 0)
        XCTAssertEqual(replacement.fetchCalls.count, 1)
        XCTAssertEqual(replacement.saveCalls.count, 1)
    }

    func testInstall_whenTrackerLifetimeEnds_shouldNotRetainTrackerAndShouldForward() throws {
        // -- Arrange --
        weak var weakTracker: MockCoreDataTracker?
        autoreleasepool {
            let tracker = MockCoreDataTracker()
            weakTracker = tracker
            integration = makeIntegration(tracker: tracker)
            integration = nil
        }

        // -- Act --
        let result = try coreDataStack.managedObjectContext.fetch(NSFetchRequest<TestEntity>(entityName: "TestEntity"))
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertNil(weakTracker)
        XCTAssertFalse(isTrackingActive)
        XCTAssertTrue(result.isEmpty)
    }
}

private struct CoreDataTestDependencies: SentryCoreDataTrackerBuilder {
    let tracker: MockCoreDataTracker

    func getCoreDataTracker(_ options: Options) -> SentryCoreDataTrackerProtocol {
        tracker
    }
}

private final class MockCoreDataTracker: SentryCoreDataTrackerProtocol {
    struct FetchCall {
        let entityName: String?
    }

    struct SaveCall {
        let hasChanges: Bool
    }

    var fetchCalls: [FetchCall] = []
    var saveCalls: [SaveCall] = []

    func managedObjectContext(
        _ context: NSManagedObjectContext,
        executeFetchRequest request: NSFetchRequest<NSFetchRequestResult>,
        error: NSErrorPointer,
        originalImp: (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?
    ) -> NSArray? {
        fetchCalls.append(FetchCall(entityName: request.entityName))
        return originalImp(request, error)
    }

    func managedObjectContext(
        _ context: NSManagedObjectContext,
        save error: NSErrorPointer,
        originalImp: (NSErrorPointer) -> Bool
    ) -> Bool {
        saveCalls.append(SaveCall(hasChanges: context.hasChanges))
        return originalImp(error)
    }
}
