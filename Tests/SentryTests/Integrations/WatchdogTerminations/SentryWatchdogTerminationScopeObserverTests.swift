#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationScopeObserverTests: XCTestCase {
    private class Fixture {
        let breadcrumbProcessor: TestSentryWatchdogTerminationBreadcrumbProcessor
        let contextProcessor: TestSentryWatchdogTerminationContextProcessor
        let userProcessor: TestSentryWatchdogTerminationUserProcessor
        let tagsProcessor: TestSentryWatchdogTerminationTagsProcessor
        let distProcessor: TestSentryWatchdogTerminationDistProcessor
        let environmentProcessor: TestSentryWatchdogTerminationEnvironmentProcessor
        let extrasProcessor: TestSentryWatchdogTerminationExtrasProcessor
        let traceContextProcessor: TestSentryWatchdogTerminationTraceContextProcessor

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

        init() throws {
            let fileManager = try TestFileManager(options: Options())
            breadcrumbProcessor = TestSentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: 10,
                fileManager: fileManager
            )
            contextProcessor = TestSentryWatchdogTerminationContextProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeContextStore: SentryScopeContextPersistentStore(fileManager: fileManager)
            )
            userProcessor = TestSentryWatchdogTerminationUserProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeUserStore: SentryScopeUserPersistentStore(fileManager: fileManager)
            )
            tagsProcessor = TestSentryWatchdogTerminationTagsProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeTagsStore: SentryScopeTagsPersistentStore(fileManager: fileManager)
            )
            distProcessor = TestSentryWatchdogTerminationDistProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeDistStore: SentryScopeDistPersistentStore(fileManager: fileManager)
            )
            environmentProcessor = TestSentryWatchdogTerminationEnvironmentProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeEnvironmentStore: SentryScopeEnvironmentPersistentStore(fileManager: fileManager)
            )
            extrasProcessor = TestSentryWatchdogTerminationExtrasProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeExtrasStore: SentryScopeExtrasPersistentStore(fileManager: fileManager)
            )
            traceContextProcessor = TestSentryWatchdogTerminationTraceContextProcessor(
                withDispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                scopeTraceContextStore: SentryScopeTraceContextPersistentStore(fileManager: fileManager)
            )
        }

        func getSut() -> SentryWatchdogTerminationScopeObserver {
            return SentryWatchdogTerminationScopeObserver(
                breadcrumbProcessor: breadcrumbProcessor,
                contextProcessor: contextProcessor,
                userProcessor: userProcessor,
                tagsProcessor: tagsProcessor,
                distProcessor: distProcessor,
                environmentProcessor: environmentProcessor,
                extrasProcessor: extrasProcessor,
                traceContextProcessor: traceContextProcessor
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
        let contextProcessorClearInvocations = fixture.contextProcessor.clearInvocations.count
        XCTAssertEqual(fixture.contextProcessor.clearInvocations.count, contextProcessorClearInvocations)
        let userProcessorClearInvocations = fixture.userProcessor.clearInvocations.count
        XCTAssertEqual(fixture.userProcessor.clearInvocations.count, userProcessorClearInvocations)
        let tagsProcessorClearInvocations = fixture.tagsProcessor.clearInvocations.count
        XCTAssertEqual(fixture.tagsProcessor.clearInvocations.count, tagsProcessorClearInvocations)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(fixture.breadcrumbProcessor.clearInvocations.count, 1)
        XCTAssertEqual(fixture.contextProcessor.clearInvocations.count, contextProcessorClearInvocations + 1)
        XCTAssertEqual(fixture.userProcessor.clearInvocations.count, userProcessorClearInvocations + 1)
        XCTAssertEqual(fixture.tagsProcessor.clearInvocations.count, tagsProcessorClearInvocations + 1)
    }

    func testClear_shouldInvokeClearForContextProcessor() {
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

    func testSetContext_whenContextIsNil_shouldCallContextProcessorSetContext() throws {
        // -- Act --
        sut.setContext(nil)

        // -- Assert --
        XCTAssertEqual(fixture.contextProcessor.setContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.contextProcessor.setContextInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetContext_whenContextIsDefined_shouldCallContextProcessorSetContext() throws {
        // -- Arrange --
        let context = fixture.context

        // -- Act --
        sut.setContext(context)

        // -- Assert --
        XCTAssertEqual(fixture.contextProcessor.setContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.contextProcessor.setContextInvocations.first)
        let invocationContext = try XCTUnwrap(invocation)
        // Use NSDictionary to erase the type information and compare the dictionaries
        XCTAssertEqual(NSDictionary(dictionary: invocationContext), NSDictionary(dictionary: context))
    }
    
    func testSetContext_whenUserIsNil_shouldCallUserProcessorSetUser() throws {
        // -- Act --
        sut.setUser(nil)

        // -- Assert --
        XCTAssertEqual(fixture.userProcessor.setUserInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.userProcessor.setUserInvocations.first)
        XCTAssertNil(invocation)
    }

    func testSetContext_whenUserIsDefined_shouldCallUserProcessorSetUser() throws {
        // -- Arrange --
        let user = fixture.user

        // -- Act --
        sut.setUser(user)

        // -- Assert --
        XCTAssertEqual(fixture.userProcessor.setUserInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.userProcessor.setUserInvocations.first)
        let invocationUser = try XCTUnwrap(invocation)
        XCTAssertEqual(invocationUser.userId, user.userId)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
