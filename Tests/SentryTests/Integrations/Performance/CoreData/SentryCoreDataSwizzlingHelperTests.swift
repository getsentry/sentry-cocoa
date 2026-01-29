@_spi(Private) import _SentryPrivate
import CoreData
import Foundation
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

// MARK: - Tests

final class SentryCoreDataSwizzlingHelperTests: XCTestCase {

    private var coreDataStack: TestCoreDataStack!
    private var mockTracker: MockCoreDataTracker!

    override func setUp() {
        super.setUp()

        coreDataStack = TestCoreDataStack(databaseFilename: "db-swizzling-\(UUID().uuidString).sqlite")
        mockTracker = MockCoreDataTracker()
    }

    override func tearDown() {
        SentryCoreDataSwizzlingHelper.stop()
        XCTAssertFalse(SentryCoreDataSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after stop called")

        coreDataStack.reset()

        super.tearDown()
    }

    private func swizzle() {
        SentryCoreDataSwizzlingHelper.swizzle(withTracker: mockTracker as Any)
        XCTAssertTrue(SentryCoreDataSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    // MARK: - Fetch Tests

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

        // Verify swizzling is working first
        _ = try coreDataStack.managedObjectContext.fetch(fetch)
        XCTAssertEqual(mockTracker.fetchCalls.count, 1, "Should track call when swizzled")

        // -- Act --
        SentryCoreDataSwizzlingHelper.stop()
        _ = try coreDataStack.managedObjectContext.fetch(fetch)

        // -- Assert --
        XCTAssertEqual(mockTracker.fetchCalls.count, 1, "Should not track new calls after stop called")
    }

    // MARK: - Save Tests

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
        // The tracker should still be called, but it will detect there are no changes
        // and not create a span. We're just testing the swizzling calls the tracker.
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should call tracker even with no changes")
    }

    func testSave_whenStop_shouldNotCallTracker() throws {
        // -- Arrange --
        swizzle()
        let entity1: TestEntity = coreDataStack.getEntity()
        entity1.field1 = "First Update"

        // Verify swizzling is working first
        try coreDataStack.managedObjectContext.save()
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should track call when swizzled")

        // -- Act --
        SentryCoreDataSwizzlingHelper.stop()
        let entity2: TestEntity = coreDataStack.getEntity()
        entity2.field1 = "Second Update"
        try coreDataStack.managedObjectContext.save()

        // -- Assert --
        XCTAssertEqual(mockTracker.saveCalls.count, 1, "Should not track new calls after stop called")
    }

    // MARK: - Swizzling State Tests

    func testSwizzlingActive_whenSwizzled_shouldBeTrue() {
        // -- Arrange & Act --
        swizzle()

        // -- Assert --
        XCTAssertTrue(SentryCoreDataSwizzlingHelper.swizzlingActive(), "Swizzling should be active after swizzle call")
    }

    func testSwizzlingActive_whenStopCalled_shouldBeFalse() {
        // -- Arrange --
        swizzle()
        XCTAssertTrue(SentryCoreDataSwizzlingHelper.swizzlingActive(), "Swizzling should initially be active")

        // -- Act --
        SentryCoreDataSwizzlingHelper.stop()

        // -- Assert --
        XCTAssertFalse(SentryCoreDataSwizzlingHelper.swizzlingActive(), "Swizzling should be inactive after stop called")

        // Re-enable for proper tearDown
        SentryCoreDataSwizzlingHelper.swizzle(withTracker: mockTracker as Any)
    }

    // MARK: - Stop Tests

    func testStop_whenCalledMultipleTimes_shouldNotCrash() {
        // -- Arrange --
        swizzle()

        // -- Act & Assert --
        // Should not crash when stop called multiple times
        SentryCoreDataSwizzlingHelper.stop()
        SentryCoreDataSwizzlingHelper.stop()
        SentryCoreDataSwizzlingHelper.stop()
    }

    // MARK: - Multiple Operations

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
}

// MARK: - Mock Tracker

private class MockCoreDataTracker: NSObject {
    struct FetchCall {
        let entityName: String?
    }

    struct SaveCall {
        let hasChanges: Bool
    }

    var fetchCalls: [FetchCall] = []
    var saveCalls: [SaveCall] = []

    @objc func managedObjectContext(
        _ context: NSManagedObjectContext,
        executeFetchRequest request: NSFetchRequest<NSFetchRequestResult>,
        error: NSErrorPointer,
        originalImp: @escaping (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> [Any]?
    ) -> [Any]? {
        fetchCalls.append(FetchCall(entityName: request.entityName))
        return originalImp(request, error)
    }

    @objc func managedObjectContext(
        _ context: NSManagedObjectContext,
        save error: NSErrorPointer,
        originalImp: @escaping (NSErrorPointer) -> Bool
    ) -> Bool {
        saveCalls.append(SaveCall(hasChanges: context.hasChanges))
        return originalImp(error)
    }
}
