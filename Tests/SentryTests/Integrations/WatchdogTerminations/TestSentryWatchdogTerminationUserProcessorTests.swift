@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// This test is used to verify the functionality of the mock of TestSentryWatchdogTerminationUserProcessor.
//
// It ensures that the mock works as expected and can be used in tests suites.
//
// Note: This file should ideally live in SentryTestUtilsTests, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtilsTests.

class TestSentryWatchdogTerminationUserProcessorTests: XCTestCase {

    private static let dsn = TestConstants.dsnForTestCase(type: TestSentryWatchdogTerminationUserProcessorTests.self)

    private class Fixture {

        let dispatchQueueWrapper: SentryDispatchQueueWrapper
        let fileManager: SentryFileManager
        let scopeUserStore: SentryScopeUserPersistentStore

        init() throws {
            let options = Options()
            options.dsn = TestSentryWatchdogTerminationUserProcessorTests.dsn
            fileManager = try TestFileManager(options: options)

            dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            scopeUserStore = SentryScopeUserPersistentStore(fileManager: fileManager)
        }

        func getSut() -> TestSentryWatchdogTerminationUserProcessor {
            return TestSentryWatchdogTerminationUserProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeUserStore: scopeUserStore
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestSentryWatchdogTerminationUserProcessor!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testSetUser_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setUserInvocations.removeAll()
        XCTAssertEqual(sut.setUserInvocations.count, 0)

        // -- Act --
        sut.setUser(User(userId: "1"))
        sut.setUser(User(userId: "2"))
        sut.setUser(nil)

        // -- Assert --
        XCTAssertEqual(sut.setUserInvocations.count, 3)
        XCTAssertEqual((sut.setUserInvocations.invocations.element(at: 0) as? User)?.userId, "1")
        XCTAssertEqual((sut.setUserInvocations.invocations.element(at: 1) as? User)?.userId, "2")
        // Use unwrap because the return type of element(at:) is double-wrapped optional [String: [String: String]]??
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
