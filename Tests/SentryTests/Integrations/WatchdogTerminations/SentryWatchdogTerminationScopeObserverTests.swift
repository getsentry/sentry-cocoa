#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationScopeObserverTests: XCTestCase {
    private class Fixture {
        let breadcrumbProcessor: TestSentryWatchdogTerminationBreadcrumbProcessor
        let attributesProcessor: TestSentryWatchdogTerminationAttributesProcessor

        let breadcrumb: [String: Any] = [
            "type": "default",
            "category": "default"
        ]
        let context: [String: [String: Any]] = [
            "device": [
                "device.class": "iPhone",
                "os": "iOS"
            ],
            "app": [
                "app.id": 123,
                "app.name": "ExampleApp"
            ]
        ]
        let user: User = User(userId: "123")
        let dist = "1.0.0"
        let env = "prod"

        init() throws {
            let fileManager = try TestFileManager(options: Options())
            breadcrumbProcessor = TestSentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: 10,
                fileManager: fileManager
            )
            attributesProcessor = try TestSentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopePersistentStore: XCTUnwrap(SentryScopePersistentStore(fileManager: fileManager))
            )
        }

        func getSut() -> SentryWatchdogTerminationScopeObserver {
            return SentryWatchdogTerminationScopeObserver(
                breadcrumbProcessor: breadcrumbProcessor,
                attributesProcessor: attributesProcessor
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationScopeObserver!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testClear_shouldInvokeClearForAllProcessors() {
        // -- Arrange --
        // Assert the preconditions
        XCTAssertEqual(fixture.breadcrumbProcessor.clearInvocations.count, 0)

        // The context process is calling clear in the initializer on purpose.
        // Therefore we compare the later count with the current count.
        let attributesProcessorClearInvocations = fixture.attributesProcessor.clearInvocations.count
        XCTAssertEqual(fixture.attributesProcessor.clearInvocations.count, attributesProcessorClearInvocations)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(fixture.breadcrumbProcessor.clearInvocations.count, 1)
        XCTAssertEqual(fixture.attributesProcessor.clearInvocations.count, attributesProcessorClearInvocations + 1)
    }

    func testClear_shouldInvokeClearForAttributesProcessor() {
        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(fixture.breadcrumbProcessor.clearInvocations.count, 1)
    }

    func testAddSerializedBreadcrumb_shouldAddToBreadcrumbProcessor() throws {
        // -- Arrange --
        let breadcrumb = fixture.breadcrumb

        // -- Act --
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        XCTAssertEqual(fixture.breadcrumbProcessor.addSerializedBreadcrumbInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.breadcrumbProcessor.addSerializedBreadcrumbInvocations.first)
        // Use NSDictionary to erase the type information and compare the dictionaries
        XCTAssertEqual(NSDictionary(dictionary: invocation), NSDictionary(dictionary: breadcrumb))
    }

    func testClearBreadcrumbs_shouldCallBreadcrumbProcessorClear() {
        // -- Arrange --
        // Assert the preconditions
        XCTAssertEqual(fixture.breadcrumbProcessor.clearBreadcrumbsInvocations.count, 0)

        // -- Act --
        sut.clearBreadcrumbs()

        // -- Assert --
        XCTAssertEqual(fixture.breadcrumbProcessor.clearBreadcrumbsInvocations.count, 1)
    }

    func testSetContext_whenContextIsNil_shouldCallAttributesProcessorSetContext() throws {
        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setContextInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetContext_whenContextIsDefined_shouldCallAttributesProcessorSetContext() throws {
        // -- Arrange --
        let context = fixture.context

        // -- Act --
        sut.setContext(context)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setContextInvocations.first)
        let invocationContext = try XCTUnwrap(invocation)
        // Use NSDictionary to erase the type information and compare the dictionaries
        XCTAssertEqual(NSDictionary(dictionary: invocationContext), NSDictionary(dictionary: context))
    }
    
    func testSetUser_whenUserIsNil_shouldCallAttributesProcessorSetUser() throws {
        // -- Act --
        sut.setUser(nil)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setUserInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setUserInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetUser_whenUserIsDefined_shouldCallAttributesProcessorSetUser() throws {
        // -- Arrange --
        let user = fixture.user

        // -- Act --
        sut.setUser(user)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setUserInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setUserInvocations.first)
        let invocationContext = try XCTUnwrap(invocation)
        XCTAssertEqual(invocationContext, user)
    }
    
    func testSetDist_whenDistIsNil_shouldCallAttributesProcessorSetDist() throws {
        // -- Act --
        sut.setDist(nil)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setDistInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setDistInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetDist_whenDistIsDefined_shouldCallAttributesProcessorSetDist() throws {
        // -- Arrange --
        let dist = fixture.dist

        // -- Act --
        sut.setDist(dist)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setDistInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setDistInvocations.first)
        let invocationContext = try XCTUnwrap(invocation)
        XCTAssertEqual(invocationContext, dist)
    }
    
    func testSetEnvironment_whenEnvironmentIsNil_shouldCallAttributesProcessorSetEnvironment() throws {
        // -- Act --
        sut.setEnvironment(nil)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setEnvironmentInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setEnvironmentInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetEnvironment_whenEnvironmentIsDefined_shouldCallAttributesProcessorSetEnvironment() throws {
        // -- Arrange --
        let env = fixture.env

        // -- Act --
        sut.setEnvironment(env)

        // -- Assert --
        XCTAssertEqual(fixture.attributesProcessor.setEnvironmentInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.attributesProcessor.setEnvironmentInvocations.first)
        let invocationContext = try XCTUnwrap(invocation)
        XCTAssertEqual(invocationContext, env)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
