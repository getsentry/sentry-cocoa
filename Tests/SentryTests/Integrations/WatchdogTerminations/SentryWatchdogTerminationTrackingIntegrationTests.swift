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

            let scopeContextPersistentStore = try XCTUnwrap(TestSentryScopeContextPersistentStore(fileManager: fileManager))
            watchdogTerminationContextProcessor = TestSentryWatchdogTerminationContextProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopeContextStore: scopeContextPersistentStore
            )
            container.watchdogTerminationContextProcessor = watchdogTerminationContextProcessor

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
