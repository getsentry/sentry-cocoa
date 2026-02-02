#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationIntegrationTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationIntegrationTests.self)

    private class Fixture {
        let options: Options

        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let processInfoWrapper: MockSentryProcessInfo
        let watchdogTerminationAttributesProcessor: TestSentryWatchdogTerminationAttributesProcessor
        let hub: SentryHubInternal
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

            let dateProvider = TestCurrentDateProvider()
            let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

            processInfoWrapper = MockSentryProcessInfo()
            container.processInfoWrapper = processInfoWrapper

            crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
            container.crashWrapper = crashWrapper

            fileManager = try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
            container.fileManager = fileManager

            let notificationCenterWrapper = TestNSNotificationCenterWrapper()
            SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueueWrapper
            SentryDependencyContainer.sharedInstance().notificationCenterWrapper = notificationCenterWrapper
            appStateManager = SentryAppStateManager(
                releaseName: options.releaseName,
                crashWrapper: crashWrapper,
                fileManager: fileManager,
                sysctlWrapper: SentryDependencyContainer.sharedInstance().sysctlWrapper
            )
            container.appStateManager = appStateManager
            appStateManager.start()

            let scopeContextPersistentStore = try XCTUnwrap(TestSentryScopePersistentStore(fileManager: fileManager))
            watchdogTerminationAttributesProcessor = TestSentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopePersistentStore: scopeContextPersistentStore
            )
            container.watchdogTerminationAttributesProcessor = watchdogTerminationAttributesProcessor

            let client = TestClient(options: options)
            scope = Scope()
            hub = SentryHubInternal(client: client, andScope: scope, andCrashWrapper: crashWrapper, andDispatchQueue: dispatchQueueWrapper)
            SentrySDKInternal.setCurrentHub(hub)
        }

        func getSut() -> SentryWatchdogTerminationTrackingIntegration<SentryDependencyContainer>? {
            let container = SentryDependencyContainer.sharedInstance()
            return SentryWatchdogTerminationTrackingIntegration(with: options, dependencies: container)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTrackingIntegration<SentryDependencyContainer>!

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
    func testInit_withXCTestConfigurationFilePathInProcessEnvironment_shouldReturnNil() throws {
        // -- Arrange --
        // Make sure that the XCTestConfigurationFilePath is set.
        fixture.processInfoWrapper.overrides.environment = [
            "XCTestConfigurationFilePath": "test_configuration_file_path"
        ]

        // -- Act --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: container)

        // -- Assert --
        XCTAssertNil(sut)
    }

    func testInit_withTestConfigurationFilePathDefined_shouldReturnNil() {
        // -- Arrange --
        // Make sure that the XCTestConfigurationFilePath is set.
        fixture.processInfoWrapper.overrides.environment = [
            "XCTestConfigurationFilePath": "test_configuration_file_path"
        ]

        // -- Act --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: container)

        // -- Assert --
        XCTAssertNil(sut)
    }

    func testInit_withOptionEnableWatchdogTerminationTrackingDisabled_shouldReturnNil() throws {
        // -- Arrange --
        let options = fixture.options
        options.enableWatchdogTerminationTracking = false

        let fixture = try Fixture(options: options)

        // -- Act --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: container)

        // -- Assert --
        XCTAssertNil(sut)
    }

    func testInit_withOptionEnableCrashHandlerDisabled_shouldReturnNil() throws {
        // -- Arrange --
        let options = fixture.options
        options.enableCrashHandler = false

        let fixture = try Fixture(options: options)

        // -- Act --
        let container = SentryDependencyContainer.sharedInstance()
        let sut = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: container)

        // -- Assert --
        XCTAssertNil(sut)
    }

    func testInit_whenNoUnitTests_trackerInitialized() throws {
        let dependencies = MockDependencies()
        _ = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: dependencies)

        XCTAssertTrue(dependencies.getWatchdogTerminationTrackerCalled)
    }

    func testInit_shouldAddScopeObserverToHub() throws {
        // -- Arrange --
        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setTagsInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setFingerprintInvocations.count, 0)

        // -- Act --
        _ = fixture.getSut()
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.count, 1)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.count, 1)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.count, 1)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.count, 1)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.count, 1)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setFingerprintInvocations.count, 1)
        fixture.scope.setContext(value: ["key": "value"], key: "foo")
        fixture.scope.setUser(User(userId: "user1234"))
        fixture.scope.setDist("dist-124")
        fixture.scope.setEnvironment("test")
        fixture.scope.setTags(["tag1": "value1", "tag2": "value2"])
        fixture.scope.setExtras(["key": "value"])
        fixture.scope.setFingerprint(["fingerprint1", "fingerprint2"])

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.count, 2)
        let contextInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.last)
        XCTAssertEqual(contextInvocation?["foo"] as? [String: String], ["key": "value"])
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.count, 2)
        let userInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.last)
        XCTAssertEqual(userInvocation?.userId, "user1234")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.count, 2)
        let distInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.last)
        XCTAssertEqual(distInvocation, "dist-124")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.count, 2)
        let envInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.last)
        XCTAssertEqual(envInvocation, "test")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setTagsInvocations.count, 2)
        let tagsInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setTagsInvocations.last)
        XCTAssertEqual(tagsInvocation, ["tag1": "value1", "tag2": "value2"])
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.count, 2)
        let extrasInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.last)
        XCTAssertEqual(extrasInvocation?["key"] as? String, "value")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setFingerprintInvocations.count, 2)
    }

    func testInit_shouldSetCurrentContextOnScopeObserver() throws {
        // -- Arrange --
        fixture.scope.contextDictionary = ["foo": ["key": "value"]]
        fixture.scope.userObject = User(userId: "user1234")
        fixture.scope.distString = "dist-124"
        fixture.scope.environmentString = "test"
        fixture.scope.tagDictionary = ["tag1": "value1", "tag2": "value2"]
        fixture.scope.propagationContext = SentryPropagationContext(traceId: SentryId(uuidString: "12345678123456781234567812345678"), spanId: SpanId(value: "1234567812345678"))
        fixture.scope.extraDictionary = ["key": "value"]
        fixture.scope.fingerprintArray = ["fingerprint1", "fingerprint2"]

        // Check pre-condition
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setTagsInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.count, 0)
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setFingerprintInvocations.count, 0)

        // -- Act --
        _ = fixture.getSut()

        // -- Assert --
        // As the instance of the scope observer is dynamically created by the dependency container,
        // we extend the tested scope by expecting the scope observer to forward the context to the
        // context processor and assert that it was called.
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.count, 1)
        let contextInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setContextInvocations.first)
        XCTAssertEqual(contextInvocation as? [String: [String: String]]?, ["foo": ["key": "value"]])
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.count, 1)
        let userInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setUserInvocations.last)
        XCTAssertEqual(userInvocation?.userId, "user1234")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.count, 1)
        let distInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setDistInvocations.last)
        XCTAssertEqual(distInvocation, "dist-124")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.count, 1)
        let envInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setEnvironmentInvocations.last)
        XCTAssertEqual(envInvocation, "test")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.count, 1)
        let extrasInvocation = try XCTUnwrap(fixture.watchdogTerminationAttributesProcessor.setExtrasInvocations.last)
        XCTAssertEqual(extrasInvocation?["key"] as? String, "value")
        XCTAssertEqual(fixture.watchdogTerminationAttributesProcessor.setFingerprintInvocations.count, 1)
    }

    func testANRDetected_UpdatesAppStateToTrue() throws {
        // -- Arrange --
        fixture.crashWrapper.internalIsBeingTraced = false
        let sut = try XCTUnwrap(fixture.getSut())

        // -- Act --
        sut.anrDetected(type: .unknown)

        // -- Assert --
        let appState = try XCTUnwrap(fixture.fileManager.readAppState())
        XCTAssertTrue(appState.isANROngoing)
    }

    func testANRStopped_UpdatesAppStateToFalse() throws {
        // -- Arrange --
        fixture.crashWrapper.internalIsBeingTraced = false
        let sut = try XCTUnwrap(fixture.getSut())

        // -- Act --
        sut.anrStopped(result: nil)

        // -- Assert --
        let appState = try XCTUnwrap(fixture.fileManager.readAppState())
        XCTAssertFalse(appState.isANROngoing)
    }
}

private class MockDependencies: ANRTrackerBuilder & ProcessInfoProvider & AppStateManagerProvider & WatchdogTerminationScopeObserverBuilder & WatchdogTerminationTrackerBuilder {
    func getANRTracker(_ interval: TimeInterval) -> Sentry.SentryANRTracker {
        SentryDependencyContainer.sharedInstance().getANRTracker(interval)
    }
    
    var processInfoWrapper: any Sentry.SentryProcessInfoSource {
        SentryDependencyContainer.sharedInstance().processInfoWrapper
    }
    
    var appStateManager: Sentry.SentryAppStateManager {
        SentryDependencyContainer.sharedInstance().appStateManager
    }
    
    func getWatchdogTerminationScopeObserverWithOptions(_ options: Sentry.Options) -> any Sentry.SentryScopeObserver {
        return SentryDependencyContainer.sharedInstance().getWatchdogTerminationScopeObserverWithOptions(options)
    }
    
    var getWatchdogTerminationTrackerCalled: Bool = false
    func getWatchdogTerminationTracker(_ options: Sentry.Options) -> Sentry.SentryWatchdogTerminationTracker? {
        getWatchdogTerminationTrackerCalled = true
        return SentryDependencyContainer.sharedInstance().getWatchdogTerminationTracker(options)
    }
}

#endif // os(iOS) || os(tvOS)
