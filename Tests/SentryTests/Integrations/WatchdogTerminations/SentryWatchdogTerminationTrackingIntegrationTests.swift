#if os(iOS) || os(tvOS)

@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import _SentryPrivate
import XCTest

class SentryWatchdogTerminationIntegrationTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationIntegrationTests.self)

    private class Fixture {
        let options: Options

        let crashReporterState: TestSentryCrashReporterState
        let fileManager: SentryFileManager
        let processInfoWrapper: MockSentryProcessInfo
        let sysctl: TestSysctl
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
            sysctl = TestSysctl()
            container.sysctlWrapper = sysctl

            crashReporterState = TestSentryCrashReporterState()
            container.activeCrashReporterStateOverride = crashReporterState

            fileManager = try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
            container.fileManager = fileManager

            let notificationCenterWrapper = TestNSNotificationCenterWrapper()
            container.dispatchQueueWrapper = dispatchQueueWrapper
            container.notificationCenterWrapper = notificationCenterWrapper
            appStateManager = SentryAppStateManager(releaseName: options.releaseName, dependencies: container)
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
            hub = SentryHubInternal(client: client, andScope: scope, activeCrashReporterState: crashReporterState, andDispatchQueue: dispatchQueueWrapper)
            SentrySDKInternal.setCurrentHub(hub)
        }

        func getSut() -> SentryWatchdogTerminationTrackingIntegration<SentryDependencyContainer>? {
            SentryWatchdogTerminationTrackingIntegration(
                with: options,
                dependencies: SentryDependencyContainer.sharedInstance()
            )
        }

        @available(*, deprecated, message: "Testing deprecated watchdog terminations V2 option")
        func getSutUsingNewHangTracker() -> SentryWatchdogTerminationTrackingIntegration<SentryDependencyContainer>? {
            return getSut()
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
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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

    func testInit_runningInNotificationServiceExtension_shouldReturnNil() throws {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.usernotifications.service"]
        )
        SentryDependencyContainer.sharedInstance().extensionDetector = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
        defer { clearTestState() } // swiftlint:disable:this avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.

        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertNil(sut, "Should not install watchdog termination tracking in a Notification Service Extension")
    }

    func testInit_runningInWidgetExtension_shouldReturnNil() throws {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]
        )
        SentryDependencyContainer.sharedInstance().extensionDetector = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
        defer { clearTestState() } // swiftlint:disable:this avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.

        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertNil(sut, "Should not install watchdog termination tracking in a Widget extension")
    }

    func testInit_runningInUnknownExtension_shouldInstall() throws {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.unknown-extension"]
        )
        SentryDependencyContainer.sharedInstance().extensionDetector = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
        defer { clearTestState() } // swiftlint:disable:this avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.

        // -- Act --
        let sut = fixture.getSut()

        // -- Assert --
        XCTAssertNotNil(sut, "Should install watchdog termination tracking in an unknown extension type")
    }

    func testInit_whenNoUnitTests_trackerInitialized() throws {
        let dependencies = MockDependencies()
        _ = SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: dependencies)

        XCTAssertTrue(dependencies.getWatchdogTerminationTrackerCalled)
        XCTAssertTrue(dependencies.getWatchdogTerminationBreadcrumbProcessorCalled)
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

    func testUninstall_shouldFlushAndCloseBreadcrumbProcessor() throws {
        // -- Arrange --
        let breadcrumbProcessor = MockWatchdogTerminationBreadcrumbProcessor()
        let dependencies = MockDependencies(breadcrumbProcessor: breadcrumbProcessor)
        let sut = try XCTUnwrap(
            SentryWatchdogTerminationTrackingIntegration(with: fixture.options, dependencies: dependencies)
        )

        // -- Act --
        sut.uninstall()

        // -- Assert --
        XCTAssertEqual(breadcrumbProcessor.flushAndCloseInvocations.count, 1)
    }
}

typealias MockDependenciesProtocol = ProcessInfoProvider & AppStateManagerProvider & WatchdogTerminationTrackerBuilder & ExtensionDetectorProvider & DateProviderProvider & ApplicationProvider & WatchdogTerminationAttributesProcessorProvider & WatchdogTerminationBreadcrumbProcessorProvider
private class MockDependencies: MockDependenciesProtocol {

    private let injectedBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor?

    init(breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor? = nil) {
        injectedBreadcrumbProcessor = breadcrumbProcessor
    }

    var dateProvider: SentryCurrentDateProvider { TestCurrentDateProvider() }

    func application() -> SentryApplication? { nil }

    var processInfoWrapper: any SentryProcessInfoSource {
        SentryDependencyContainer.sharedInstance().processInfoWrapper
    }

    var appStateManager: SentryAppStateManager {
        SentryDependencyContainer.sharedInstance().appStateManager
    }

    var watchdogTerminationAttributesProcessor: SentryWatchdogTerminationAttributesProcessor {
        SentryDependencyContainer.sharedInstance().watchdogTerminationAttributesProcessor
    }

    var getWatchdogTerminationTrackerCalled: Bool = false
    func getWatchdogTerminationTracker(_ options: Options) -> SentryWatchdogTerminationTracker? {
        getWatchdogTerminationTrackerCalled = true
        return SentryDependencyContainer.sharedInstance().getWatchdogTerminationTracker(options)
    }

    var getWatchdogTerminationBreadcrumbProcessorCalled: Bool = false
    func getWatchdogTerminationBreadcrumbProcessor(_ options: Options) -> SentryWatchdogTerminationBreadcrumbProcessor? {
        getWatchdogTerminationBreadcrumbProcessorCalled = true
        if let injectedBreadcrumbProcessor {
            return injectedBreadcrumbProcessor
        }
        return SentryDependencyContainer.sharedInstance().getWatchdogTerminationBreadcrumbProcessor(options)
    }

    var extensionDetector: SentryExtensionDetector {
        SentryDependencyContainer.sharedInstance().extensionDetector
    }
}

#endif // os(iOS) || os(tvOS)
