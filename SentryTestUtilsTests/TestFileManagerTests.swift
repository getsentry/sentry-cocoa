@_spi(Private) @testable import SentryTestUtils
import XCTest

class TestFileManagerTests: XCTestCase {

    private class Fixture {
        fileprivate var dateProvider = TestCurrentDateProvider()
        fileprivate var dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        fileprivate var options: Options!

        init(testName: String) {
            options = Options()
            options.dsn = TestConstants.dsnForTestCase(type: TestFileManagerTests.self, testName: testName)

            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
            // Define a fixed date so that the unique file paths are deterministic.
            dateProvider.setDate(date: Date(timeIntervalSince1970: 1_000_000))
        }

        func getSut() throws -> TestFileManager {
            return try TestFileManager(options: options)
        }

        func getActualFileManagerSut() throws -> SentryFileManager {
            return try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestFileManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        fixture = Fixture(testName: self.name)
        sut = try fixture.getSut()
    }

    func testStore_whenStoreEnvelopePathNilIsTrue_shouldRecordInvocationAndReturnNil() {
        // -- Arrange --
        let envelope = TestConstants.envelope

        // -- Act --
        sut.storeEnvelopePathNil = true
        let result1 = sut.store(envelope)
        let result2 = sut.store(envelope)

        // -- Assert --
        XCTAssertNil(result1)
        XCTAssertNil(result2)
        XCTAssertEqual(sut.storeEnvelopeInvocations.count, 2)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 0), envelope)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 1), envelope)
    }

    func testStore_whenStoreEnvelopePathNilIsFalse_whenMockPathIsDefined_shouldRecordInvocationAndReturnMockPath() {
        // -- Arrange --
        let envelope = TestConstants.envelope

        // -- Act --
        sut.storeEnvelopePathNil = false
        sut.storeEnvelopePath = "/some/path"
        let result1 = sut.store(envelope)
        let result2 = sut.store(envelope)

        // -- Assert --
        XCTAssertEqual(result1, "/some/path")
        XCTAssertEqual(result2, "/some/path")
        XCTAssertEqual(sut.storeEnvelopeInvocations.count, 2)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 0), envelope)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 1), envelope)
    }

    func testStore_whenStoreEnvelopePathNilIsFalse_whenMockPathIsNotDefined_shouldRecordInvocationAndReturnActualPath() throws {
        // -- Arrange --
        let envelope = TestConstants.envelope

        let actualFileManager = try fixture.getActualFileManagerSut()
        let actualEnvelopePath1 = try XCTUnwrap(actualFileManager.store(envelope))
        let actualEnvelopePath2 = try XCTUnwrap(actualFileManager.store(envelope))
        let trimmedActualPath1 = actualEnvelopePath1.dropLast(5).dropLast(36)
        let trimmedActualPath2 = actualEnvelopePath2.dropLast(5).dropLast(36)

        // -- Act --
        sut.storeEnvelopePathNil = false
        sut.storeEnvelopePath = nil
        let result1 = try XCTUnwrap(sut.store(envelope))
        let result2 = try XCTUnwrap(sut.store(envelope))

        // -- Assert --
        // The paths are ending in a unique UUID, so we can only compare the prefix excluding the last 32 random characters and the `.json` extension
        XCTAssertTrue(result1.hasPrefix(trimmedActualPath1) == true)
        XCTAssertTrue(result2.hasPrefix(trimmedActualPath2) == true)
        XCTAssertEqual(sut.storeEnvelopeInvocations.count, 2)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 0), envelope)
        XCTAssertEqual(sut.storeEnvelopeInvocations.invocations.element(at: 1), envelope)
    }

    func testDeleteOldEnvelopeItems_shouldRecordInvocation() {
        // -- Act --
        sut.deleteOldEnvelopeItems()
        sut.deleteOldEnvelopeItems()

        // -- Assert --
        XCTAssertEqual(sut.deleteOldEnvelopeItemsInvocations.count, 2)
    }
    
    func testReadTimestampLastInForeground_shouldRecordInvocationAndReturnTimestamp() {
        // -- Arrange --
        let expectedDate = Date()
        sut.timestampLastInForeground = expectedDate
        
        // -- Act --
        let result1 = sut.readTimestampLastInForeground()
        let result2 = sut.readTimestampLastInForeground()

        // -- Assert --
        XCTAssertEqual(sut.readTimestampLastInForegroundInvocations, 2)
        XCTAssertEqual(result1, expectedDate)
        XCTAssertEqual(result2, expectedDate)
    }
    
    func testStoreTimestampLast_shouldRecordInvocationAndStoreTimestamp() {
        // -- Arrange --
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        let date2 = Date(timeIntervalSince1970: 2_000_000)

        // -- Act --
        sut.storeTimestampLast(inForeground: date1)
        sut.storeTimestampLast(inForeground: date2)

        // -- Assert --
        XCTAssertEqual(sut.storeTimestampLastInForegroundInvocations, 2)
        XCTAssertEqual(sut.timestampLastInForeground, date2)
    }
    
    func testDeleteTimestampLastInForeground_shouldRecordInvocationAndDeleteTimestamp() {
        // -- Arrange --
        sut.timestampLastInForeground = Date()
        
        // -- Act --
        sut.deleteTimestampLastInForeground()
        sut.deleteTimestampLastInForeground()

        // -- Assert --
        XCTAssertEqual(sut.deleteTimestampLastInForegroundInvocations, 2)
        XCTAssertNil(sut.timestampLastInForeground)
    }
    
    func testReadAppState_shouldRecordInvocationAndReturnNil() {
        // -- Act --
        let result1 = sut.readAppState()
        let result2 = sut.readAppState()

        // -- Assert --
        XCTAssertEqual(sut.readAppStateInvocations.count, 2)
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }
    
    func testReadPreviousAppState_whenAppStateIsNil_shouldRecordInvocationAndReturnAppState() {
        // -- Arrange --
        sut.appState = nil

        // -- Act --
        let result1 = sut.readPreviousAppState()
        let result2 = sut.readPreviousAppState()

        // -- Assert --
        XCTAssertEqual(sut.readPreviousAppStateInvocations.count, 2)
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }

    func testReadPreviousAppState_whenAppStateIsDefined_shouldRecordInvocationAndReturnAppState() {
        // -- Arrange --
        let expectedAppState = SentryAppState(
            releaseName: "release",
            osVersion: "os",
            vendorId: "vendor-id",
            isDebugging: true,
            systemBootTimestamp: Date(timeIntervalSince1970: 5_000)
        )
        sut.appState = expectedAppState

        // -- Act --
        let result1 = sut.readPreviousAppState()
        let result2 = sut.readPreviousAppState()

        // -- Assert --
        XCTAssertEqual(sut.readPreviousAppStateInvocations.count, 2)
        XCTAssertEqual(result1, expectedAppState)
        XCTAssertEqual(result2, expectedAppState)
    }
}
