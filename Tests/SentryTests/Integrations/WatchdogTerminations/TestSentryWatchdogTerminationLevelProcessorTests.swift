@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// This test is used to verify the functionality of the mock of TestSentryWatchdogTerminationLevelProcessor.
//
// It ensures that the mock works as expected and can be used in tests suites.
//
// Note: This file should ideally live in SentryTestUtilsTests, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtilsTests.

class TestSentryWatchdogTerminationLevelProcessorTests: XCTestCase {

    private static let dsn = TestConstants.dsnForTestCase(type: TestSentryWatchdogTerminationLevelProcessorTests.self)

    private class Fixture {

        let dispatchQueueWrapper: SentryDispatchQueueWrapper
        let fileManager: SentryFileManager
        let scopeLevelStore: SentryScopeLevelPersistentStore

        init() throws {
            let options = Options()
            options.dsn = TestSentryWatchdogTerminationLevelProcessorTests.dsn
            fileManager = try TestFileManager(options: options)

            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            scopeLevelStore = SentryScopeLevelPersistentStore(fileManager: fileManager)
        }

        func getSut() -> TestSentryWatchdogTerminationLevelProcessor {
            return TestSentryWatchdogTerminationLevelProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeLevelStore: scopeLevelStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestSentryWatchdogTerminationLevelProcessor!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testSetLevel_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setLevelInvocations.removeAll()
        XCTAssertEqual(sut.setLevelInvocations.count, 0)

        // -- Act --
        sut.setLevel(NSNumber(value: SentryLevel.debug.rawValue))
        sut.setLevel(NSNumber(value: SentryLevel.error.rawValue))
        sut.setLevel(nil)

        // -- Assert --
        XCTAssertEqual(sut.setLevelInvocations.count, 3)
        XCTAssertEqual((sut.setLevelInvocations.invocations.element(at: 0) as? NSNumber)?.uintValue, SentryLevel.debug.rawValue)
        XCTAssertEqual((sut.setLevelInvocations.invocations.element(at: 1) as? NSNumber)?.uintValue, SentryLevel.error.rawValue)
        // Use unwrap because the return type of element(at:) is double-wrapped optional NSNumber??
        let thirdInvocation = try XCTUnwrap(sut.setLevelInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }

    func testClear_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.clearInvocations.removeAll()
        XCTAssertEqual(sut.clearInvocations.count, 0)

        // -- Act --
        sut.clear()
        sut.clear()
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.clearInvocations.count, 3)
    }
}
