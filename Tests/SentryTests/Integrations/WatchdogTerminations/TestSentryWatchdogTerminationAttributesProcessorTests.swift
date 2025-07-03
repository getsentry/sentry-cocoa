@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// This test is used to verify the functionality of the mock of TestSentryWatchdogTerminationAttributesProcessor.
//
// It ensures that the mock works as expected and can be used in tests suites.
//
// Note: This file should ideally live in SentryTestUtilsTests, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtilsTests.

class TestSentryWatchdogTerminationAttributesProcessorTests: XCTestCase {

    private static let dsn = TestConstants.dsnForTestCase(type: TestSentryWatchdogTerminationAttributesProcessorTests.self)

    private class Fixture {

        let dispatchQueueWrapper: SentryDispatchQueueWrapper
        let fileManager: SentryFileManager
        let scopePersistentStore: SentryScopePersistentStore

        init() throws {
            let options = Options()
            options.dsn = TestSentryWatchdogTerminationAttributesProcessorTests.dsn
            fileManager = try TestFileManager(options: options)

            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            scopePersistentStore = try XCTUnwrap(SentryScopePersistentStore(fileManager: fileManager))
        }

        func getSut() -> TestSentryWatchdogTerminationAttributesProcessor {
            return TestSentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopePersistentStore: scopePersistentStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestSentryWatchdogTerminationAttributesProcessor!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testSetContext_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setContextInvocations.removeAll()
        XCTAssertEqual(sut.setContextInvocations.count, 0)

        // -- Act --
        sut.setContext(["key": ["value": "test"]])
        sut.setContext(["key2": ["value2": "test2"]])
        sut.setContext(nil)

        // -- Assert --
        XCTAssertEqual(sut.setContextInvocations.count, 3)
        XCTAssertEqual(
            sut.setContextInvocations.invocations.element(at: 0) as? [String: [String: String]]?,
            ["key": ["value": "test"]]
        )
        XCTAssertEqual(sut.setContextInvocations.invocations.element(at: 1) as? [String: [String: String]]?, ["key2": ["value2": "test2"]])
        // Use unwrap because the return type of element(at:) is double-wrapped optional [String: [String: String]]??
        let thirdInvocation = try XCTUnwrap(sut.setContextInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }
    
    func testSetUser_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setContextInvocations.removeAll()
        XCTAssertEqual(sut.setContextInvocations.count, 0)

        // -- Act --
        sut.setUser(User(userId: "user1234"))
        sut.setUser(User(userId: "anotherUser"))
        sut.setUser(nil)

        // -- Assert --
        XCTAssertEqual(sut.setUserInvocations.count, 3)
        XCTAssertEqual(
            sut.setUserInvocations.invocations.element(at: 0)??.userId,
            "user1234"
        )
        XCTAssertEqual(sut.setUserInvocations.invocations.element(at: 1)??.userId, "anotherUser")
        let thirdInvocation = try XCTUnwrap(sut.setUserInvocations.invocations.element(at: 2))
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
