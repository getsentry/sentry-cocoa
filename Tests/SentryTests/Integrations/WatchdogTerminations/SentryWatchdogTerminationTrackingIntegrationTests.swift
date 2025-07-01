#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationIntegrationTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationIntegrationTests.self)

    private class Fixture {
        let options: Options

        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let processInfoWrapper: TestSentryNSProcessInfoWrapper
        let watchdogTerminationContextProcessor: TestSentryWatchdogTerminationContextProcessor
        let watchdogTerminationUserProcessor: TestSentryWatchdogTerminationUserProcessor
        let watchdogTerminationTagsProcessor: TestSentryWatchdogTerminationTagsProcessor
        let watchdogTerminationDistProcessor: TestSentryWatchdogTerminationDistProcessor
        let watchdogTerminationEnvironmentProcessor: TestSentryWatchdogTerminationEnvironmentProcessor
        let watchdogTerminationExtrasProcessor: TestSentryWatchdogTerminationExtrasProcessor
        let watchdogTerminationTraceContextProcessor: TestSentryWatchdogTerminationTraceContextProcessor

        let hub: SentryHub
        let scope: Scope
        let appStateManager: SentryAppStateManager

        convenience init() throws {
            let options = Options()
            options.dsn = SentryWatchdogTerminationIntegrationTests.dsn
            options.enableCrashHandler = true
            options.enableWatchdogTerminationTracking = true

            try self.init(options: options)
        }

        init(options: Options) throws {
            self.options = options

            let container = SentryDependencyContainer.sharedInstance()

            let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

            processInfoWrapper = TestSentryNSProcessInfoWrapper()
            container.processInfoWrapper = processInfoWrapper

            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            container.crashWrapper = crashWrapper

            fileManager = try SentryFileManager(options: options)
            container.fileManager = fileManager

            let notificationCenterWrapper = TestNSNotificationCenterWrapper()
            appStateManager = SentryAppStateManager(
                options: options,
                crashWrapper: crashWrapper,
                fileManager: fileManager,
                dispatchQueueWrapper: dispatchQueueWrapper,
                notificationCenterWrapper: notificationCenterWrapper
            )
            container.appStateManager = appStateManager
            appStateManager.start()

            let scopeContextPersistentStore = TestSentryScopeContextPersistentStore(fileManager: fileManager)
            watchdogTerminationContextProcessor = TestSentryWatchdogTerminationContextProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeContextStore: scopeContextPersistentStore
            )
            container.watchdogTerminationContextProcessor = watchdogTerminationContextProcessor
            
            let scopeUserPersistentStore = TestSentryScopeUserPersistentStore(fileManager: fileManager)
            watchdogTerminationUserProcessor = TestSentryWatchdogTerminationUserProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeUserStore: scopeUserPersistentStore
            )
            container.watchdogTerminationUserProcessor = watchdogTerminationUserProcessor

            let scopeTagsPersistentStore = TestSentryScopeTagsPersistentStore(fileManager: fileManager)
            watchdogTerminationTagsProcessor = TestSentryWatchdogTerminationTagsProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeTagsStore: scopeTagsPersistentStore
            )
            container.watchdogTerminationTagsProcessor = watchdogTerminationTagsProcessor

            let scopeDistPersistentStore = TestSentryScopeDistPersistentStore(fileManager: fileManager)
            watchdogTerminationDistProcessor = TestSentryWatchdogTerminationDistProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeDistStore: scopeDistPersistentStore
            )
            container.watchdogTerminationDistProcessor = watchdogTerminationDistProcessor

            let scopeEnvironmentPersistentStore = TestSentryScopeEnvironmentPersistentStore(fileManager: fileManager)
            watchdogTerminationEnvironmentProcessor = TestSentryWatchdogTerminationEnvironmentProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeEnvironmentStore: scopeEnvironmentPersistentStore
            )
            container.watchdogTerminationEnvironmentProcessor = watchdogTerminationEnvironmentProcessor
            
            let scopeExtrasPersistentStore = TestSentryScopeExtrasPersistentStore(fileManager: fileManager)
            watchdogTerminationExtrasProcessor = TestSentryWatchdogTerminationExtrasProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeExtrasStore: scopeExtrasPersistentStore
            )
            container.watchdogTerminationExtrasProcessor = watchdogTerminationExtrasProcessor
            
            let scopeTraceContextPersistentStore = TestSentryScopeTraceContextPersistentStore(fileManager: fileManager)
            watchdogTerminationTraceContextProcessor = TestSentryWatchdogTerminationTraceContextProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeTraceContextStore: scopeTraceContextPersistentStore
            )
            container.watchdogTerminationTraceContextProcessor = watchdogTerminationTraceContextProcessor

            let client = TestClient(options: options)
            scope = Scope()
            hub = SentryHub(client: client, andScope: scope, andCrashWrapper: crashWrapper, andDispatchQueue: dispatchQueueWrapper)
            SentrySDK.setCurrentHub(hub)
        }

        func getSut() -> SentryWatchdogTerminationTrackingIntegration {
            SentryWatchdogTerminationTrackingIntegration()
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTrackingIntegration!

    override func setUpWithError() throws {
        super.setUp()

        fixture = try Fixture()

        // Make sure that the XCTestConfigurationFilePath is not set.
        fixture.processInfoWrapper.overrides.environment = [:]
    }

    override func tearDown() {
        sut?.uninstall()
        fixture.appStateManager.stop()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
        super.tearDown()
    }

    // This unit test reflects the behaviour when installing the integration from unit tests.
    func testInit_withXCTestConfigurationFilePathInProcessEnvironment_shouldUseValue() throws {
        // -- Arrange --
        // Make sure that the XCTestConfigurationFilePath is set.
        fixture.processInfoWrapper.overrides.environment = [
            "XCTestConfigurationFilePath": "test_configuration_file_path"
        ]

        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertEqual(Dynamic(sut).testConfigurationFilePath.asString, "test_configuration_file_path")
    }

    func testInstallWithOptions_withTestConfigurationFilePathDefined_shouldNotInstall() {
        // -- Arrange --
        // Make sure that the XCTestConfigurationFilePath is set.
        fixture.processInfoWrapper.overrides.environment = [
            "XCTestConfigurationFilePath": "test_configuration_file_path"
        ]

        let sut = fixture.getSut()

        // -- Act --
        let result = sut.install(with: fixture.options)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testInstallWithOptions_withOptionEnableWatchdogTerminationTrackingDisabled_shouldNotInstall() throws {
        // -- Arrange --
        let options = fixture.options
        options.enableWatchdogTerminationTracking = false

        let fixture = try Fixture(options: options)
        let sut = fixture.getSut()

        // -- Act --
        let result = sut.install(with: fixture.options)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testInstallWithOptions_withOptionEnableCrashHandlerDisabled_shouldNotInstall() throws {
        // -- Arrange --
        let options = fixture.options
        options.enableCrashHandler = false

        let fixture = try Fixture(options: options)
        let sut = fixture.getSut()

        // -- Act --
        let result = sut.install(with: fixture.options)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testInstallWithOptions_whenNoUnitTests_trackerInitialized() {
        let sut = SentryWatchdogTerminationTrackingIntegration()
        Dynamic(sut).setTestConfigurationFilePath(nil)
        sut.install(with: Options())

        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }

    func testInstallWithOptions_shouldAddScopeObserverToHub() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationContextProcessor.setContextInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationContextProcessor.setContextInvocations.count, 1)
        fixture.scope.setContext(value: ["key": "value"], key: "foo")

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationContextProcessor.setContextInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationContextProcessor.setContextInvocations.last)
        XCTAssertEqual(invocation?["foo"] as? [String: String], ["key": "value"])
    }

    func testInstallWithOptions_shouldSetCurrentContextOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.contextDictionary = ["foo": ["key": "value"]]

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationContextProcessor.setContextInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationContextProcessor.setContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationContextProcessor.setContextInvocations.first)
        XCTAssertEqual(invocation as? [String: [String: String]]?, ["foo": ["key": "value"]])
    }
    
    func testInstallWithOptions_shouldStoreUserInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationUserProcessor.setUserInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationUserProcessor.setUserInvocations.count, 1)
        fixture.scope.setUser(User(userId: "exampleUserId"))

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationUserProcessor.setUserInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationUserProcessor.setUserInvocations.last)
        XCTAssertEqual(invocation?.userId, "exampleUserId")
    }

    func testInstallWithOptions_shouldSetCurrentUserOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.userObject = User(userId: "outerUser")

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationUserProcessor.setUserInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationUserProcessor.setUserInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationUserProcessor.setUserInvocations.first)
        XCTAssertEqual(invocation?.userId, "outerUser")
    }

    func testInstallWithOptions_shouldStoreTagsInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.count, 1)
        fixture.scope.setTag(value: "tagValue", key: "tagKey")

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the tags to the
        // tags processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.last)
        XCTAssertEqual(invocation?["tagKey"], "tagValue")
    }

    func testInstallWithOptions_shouldSetCurrentTagsOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.setTag(value: "existingTagValue", key: "existingTagKey")

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the tags to the
        // tags processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationTagsProcessor.setTagsInvocations.first)
        XCTAssertEqual(invocation?["existingTagKey"], "existingTagValue")
    }

    func testInstallWithOptions_shouldStoreDistInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationDistProcessor.setDistInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationDistProcessor.setDistInvocations.count, 1)
        fixture.scope.setDist("test-dist")

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the dist to the
        // dist processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationDistProcessor.setDistInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationDistProcessor.setDistInvocations.last)
        XCTAssertEqual(invocation, "test-dist")
    }

    func testInstallWithOptions_shouldSetCurrentDistOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.setDist("existing-dist")

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationDistProcessor.setDistInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the dist to the
        // dist processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationDistProcessor.setDistInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationDistProcessor.setDistInvocations.first)
        XCTAssertEqual(invocation, "existing-dist")
    }

    func testInstallWithOptions_shouldStoreEnvironmentInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.count, 1)
        fixture.scope.setEnvironment("test-environment")

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the environment to the
        // environment processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.last)
        XCTAssertEqual(invocation, "test-environment")
    }

    func testInstallWithOptions_shouldSetCurrentEnvironmentOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.setEnvironment("existing-environment")

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the environment to the
        // environment processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationEnvironmentProcessor.setEnvironmentInvocations.first)
        XCTAssertEqual(invocation, "existing-environment")
    }

    func testInstallWithOptions_shouldStoreExtrasInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.count, 1)
        fixture.scope.setExtras(["extra-key": "extra-value"])

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the extras to the
        // extras processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.last)
        XCTAssertEqual(invocation?["extra-key"] as? String, "extra-value")
    }

    func testInstallWithOptions_shouldSetCurrentExtrasOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        fixture.scope.setExtras(["existing-extra-key": "existing-extra-value"])

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the extras to the
        // extras processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationExtrasProcessor.setExtrasInvocations.first)
        XCTAssertEqual(invocation?["existing-extra-key"] as? String, "existing-extra-value")
    }

    func testInstallWithOptions_shouldStoreTraceContextInfo() throws {
        // -- Arrange --
        let sut = fixture.getSut()

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)
        XCTAssertEqual(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.count, 1)
        let propagationContext = SentryPropagationContext(trace: SentryId(uuidString: "1de6272b6def40a995104400e2723644"), spanId: SpanId(value: "bf2625b58c6b42f3"))
        fixture.scope.propagationContext = propagationContext

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the trace context to the
        // trace context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.count, 2)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.last)
        XCTAssertEqual(invocation?["trace_id"] as? String, "1de6272b6def40a995104400e2723644")
        XCTAssertEqual(invocation?["span_id"] as? String, "bf2625b58c6b42f3")
    }

    func testInstallWithOptions_shouldSetCurrentTraceContextOnScopeObserver() throws {
        // -- Arrange --
        let sut = fixture.getSut()
        let propagationContext = SentryPropagationContext(trace: SentryId(uuidString: "1de6272b6def40a995104400e2723645"), spanId: SpanId(value: "bf2625b58c6b42f4"))
        fixture.scope.propagationContext = propagationContext

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.count, 0)

        // -- Act --
        sut.install(with: fixture.options)

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the trace context to the
        // trace context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.count, 1)
        let invocation = try XCTUnwrap(fixture.watchdogTerminationTraceContextProcessor.setTraceContextInvocations.first)
        XCTAssertEqual(invocation?["trace_id"] as? String, "1de6272b6def40a995104400e2723645")
        XCTAssertEqual(invocation?["span_id"] as? String, "bf2625b58c6b42f4")
    }

    func testANRDetected_UpdatesAppStateToTrue() throws {
        // -- Arrange --
        fixture.crashWrapper.internalIsBeingTraced = false
        let sut = fixture.getSut()
        sut.install(with: Options())

        // -- Act --
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)

        // -- Assert --
        let appState = try XCTUnwrap(fixture.fileManager.readAppState())
        XCTAssertTrue(appState.isANROngoing)
    }

    func testANRStopped_UpdatesAppStateToFalse() throws {
        // -- Arrange --
        fixture.crashWrapper.internalIsBeingTraced = false
        let sut = fixture.getSut()
        sut.install(with: Options())

        // -- Act --
        Dynamic(sut).anrStopped()

        // -- Assert --
        let appState = try XCTUnwrap(fixture.fileManager.readAppState())
        XCTAssertFalse(appState.isANROngoing)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
