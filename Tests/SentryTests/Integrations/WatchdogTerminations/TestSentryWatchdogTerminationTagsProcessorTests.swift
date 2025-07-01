@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// This test is used to verify the functionality of the mock of TestSentryWatchdogTerminationTagsProcessor.
//
// It ensures that the mock works as expected and can be used in tests suites.
//
// Note: This file should ideally live in SentryTestUtilsTests, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtilsTests.

class TestSentryWatchdogTerminationTagsProcessorTests: XCTestCase {

    private static let dsn = TestConstants.dsnForTestCase(type: TestSentryWatchdogTerminationTagsProcessorTests.self)

    private class Fixture {

        let dispatchQueueWrapper: SentryDispatchQueueWrapper
        let fileManager: SentryFileManager
        let scopeTagsStore: SentryScopeTagsPersistentStore

        init() throws {
            let options = Options()
            options.dsn = TestSentryWatchdogTerminationTagsProcessorTests.dsn
            fileManager = try TestFileManager(options: options)

            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            scopeTagsStore = SentryScopeTagsPersistentStore(fileManager: fileManager)
        }

        func getSut() -> TestSentryWatchdogTerminationTagsProcessor {
            return TestSentryWatchdogTerminationTagsProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeTagsStore: scopeTagsStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestSentryWatchdogTerminationTagsProcessor!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testSetTags_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setTagsInvocations.removeAll()
        XCTAssertEqual(sut.setTagsInvocations.count, 0)

        // -- Act --
        sut.setTags(["a": "b"])
        sut.setTags(["c": "d"])
        sut.setTags(nil)

        // -- Assert --
        XCTAssertEqual(sut.setTagsInvocations.count, 3)
        XCTAssertEqual((sut.setTagsInvocations.invocations.element(at: 0) as? [String: String])?["a"], "b")
        XCTAssertEqual((sut.setTagsInvocations.invocations.element(at: 1) as? [String: String])?["c"], "d")
        // Use unwrap because the return type of element(at:) is double-wrapped optional [String: [String: String]]??
        let thirdInvocation = try XCTUnwrap(sut.setTagsInvocations.invocations.element(at: 2))
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
