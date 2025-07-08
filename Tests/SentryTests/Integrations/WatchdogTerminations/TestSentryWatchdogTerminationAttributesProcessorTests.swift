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
        sut.setUserInvocations.removeAll()
        XCTAssertEqual(sut.setUserInvocations.count, 0)

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
    
    func testSetDist_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setDistInvocations.removeAll()
        XCTAssertEqual(sut.setDistInvocations.count, 0)

        // -- Act --
        sut.setDist("1.0.0")
        sut.setDist("2.0.0")
        sut.setDist(nil)

        // -- Assert --
        XCTAssertEqual(sut.setDistInvocations.count, 3)
        XCTAssertEqual(
            sut.setDistInvocations.invocations.element(at: 0),
            "1.0.0"
        )
        XCTAssertEqual(sut.setDistInvocations.invocations.element(at: 1), "2.0.0")
        let thirdInvocation = try XCTUnwrap(sut.setDistInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }
    
    func testSetEnvironment_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setEnvironmentInvocations.removeAll()
        XCTAssertEqual(sut.setEnvironmentInvocations.count, 0)

        // -- Act --
        sut.setEnvironment("dev")
        sut.setEnvironment("prod")
        sut.setEnvironment(nil)

        // -- Assert --
        XCTAssertEqual(sut.setEnvironmentInvocations.count, 3)
        XCTAssertEqual(sut.setEnvironmentInvocations.invocations.element(at: 0), "dev")
        XCTAssertEqual(sut.setEnvironmentInvocations.invocations.element(at: 1), "prod")
        let thirdInvocation = try XCTUnwrap(sut.setEnvironmentInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }

    func testSetTags_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setTagsInvocations.removeAll()
        XCTAssertEqual(sut.setTagsInvocations.count, 0)

        // -- Act --
        sut.setTags(["tag1": "value1"])
        sut.setTags(["tag2": "value2", "tag3": "value3"])
        sut.setTags(nil)

        // -- Assert --
        XCTAssertEqual(sut.setTagsInvocations.count, 3)
        XCTAssertEqual(
            sut.setTagsInvocations.invocations.element(at: 0),
            ["tag1": "value1"]
        )
        XCTAssertEqual(sut.setTagsInvocations.invocations.element(at: 1), ["tag2": "value2", "tag3": "value3"])
        let thirdInvocation = try XCTUnwrap(sut.setTagsInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }
    
    func testSetExtras_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setExtrasInvocations.removeAll()
        XCTAssertEqual(sut.setExtrasInvocations.count, 0)

        // -- Act --
        let extras1: [String: Any] = ["key1": "value1", "key2": 42]
        let extras2: [String: Any] = ["key3": true, "key4": ["nested": "value"]]
        sut.setExtras(extras1)
        sut.setExtras(extras2)
        sut.setExtras(nil)

        // -- Assert --
        XCTAssertEqual(sut.setExtrasInvocations.count, 3)
        XCTAssertEqual(
            NSDictionary(dictionary: sut.setExtrasInvocations.invocations.element(at: 0) as? [String: Any] ?? [:]),
            NSDictionary(dictionary: extras1)
        )
        XCTAssertEqual(NSDictionary(dictionary: sut.setExtrasInvocations.invocations.element(at: 1) as? [String: Any] ?? [:]), NSDictionary(dictionary: extras2))
        let thirdInvocation = try XCTUnwrap(sut.setExtrasInvocations.invocations.element(at: 2))
        XCTAssertNil(thirdInvocation)
    }
    
    func testSetFingerprint_shouldRecordInvocations() throws {
        // -- Arrange --
        // Clean the invocations to ensure a clean state
        sut.setFingerprintInvocations.removeAll()
        XCTAssertEqual(sut.setFingerprintInvocations.count, 0)

        // -- Act --
        let fingerprint1 = ["fp1", "fp2"]
        let fingerprint2 = ["fp3", "fp4", "fp5"]
        sut.setFingerprint(fingerprint1)
        sut.setFingerprint(fingerprint2)
        sut.setFingerprint(nil)

        // -- Assert --
        XCTAssertEqual(sut.setFingerprintInvocations.count, 3)
        XCTAssertEqual(
            sut.setFingerprintInvocations.invocations.element(at: 0),
            fingerprint1
        )
        XCTAssertEqual(sut.setFingerprintInvocations.invocations.element(at: 1), fingerprint2)
        let thirdInvocation = try XCTUnwrap(sut.setFingerprintInvocations.invocations.element(at: 2))
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
