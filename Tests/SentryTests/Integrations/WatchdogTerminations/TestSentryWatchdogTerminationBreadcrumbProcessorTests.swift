@testable import Sentry
import SentryTestUtils
import XCTest

// This test is used to verify the functionality of the mock of TestSentryWatchdogTerminationBreadcrumbProcessor.
//
// It ensures that the mock works as expected and can be used in tests suites.
//
// Note: This file should ideally live in SentryTestUtilsTests, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtilsTests.

class TestSentryWatchdogTerminationBreadcrumbProcessorTests: XCTestCase {

    private static let dsn = TestConstants.dsnForTestCase(type: TestSentryWatchdogTerminationBreadcrumbProcessorTests.self)

    private class Fixture {
        let fileManager: SentryFileManager

        init() throws {
            let options = Options()
            options.dsn = TestSentryWatchdogTerminationBreadcrumbProcessorTests.dsn
            fileManager = try TestFileManager(options: options)
        }

        func getSut() -> TestSentryWatchdogTerminationBreadcrumbProcessor {
            return TestSentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: 10,
                fileManager: fileManager
            )
        }
    }

    private var fixture: Fixture!
    private var sut: TestSentryWatchdogTerminationBreadcrumbProcessor!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    func testSetContext_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.addSerializedBreadcrumbInvocations.removeAll()
        XCTAssertEqual(sut.addSerializedBreadcrumbInvocations.count, 0)

        // -- Act --
        sut.addSerializedBreadcrumb(["key": ["value": "test"]])
        sut.addSerializedBreadcrumb(["key2": 123])
        sut.addSerializedBreadcrumb([:])

        // -- Assert --
        XCTAssertEqual(sut.addSerializedBreadcrumbInvocations.count, 3)
        XCTAssertEqual(
            sut.addSerializedBreadcrumbInvocations.invocations.element(at: 0) as? [String: [String: String]]?,
            ["key": ["value": "test"]]
        )
        XCTAssertEqual(sut.addSerializedBreadcrumbInvocations.invocations.element(at: 1) as? [String: Int]?, ["key2": 123])
        XCTAssertEqual(sut.addSerializedBreadcrumbInvocations.invocations.element(at: 2)?.count, 0)
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

    func testClearBreadcrumbs_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.clearBreadcrumbsInvocations.removeAll()
        XCTAssertEqual(sut.clearBreadcrumbsInvocations.count, 0)

        // -- Act --
        sut.clearBreadcrumbs()
        sut.clearBreadcrumbs()
        sut.clearBreadcrumbs()

        // -- Assert --
        XCTAssertEqual(sut.clearBreadcrumbsInvocations.count, 3)
    }
}
