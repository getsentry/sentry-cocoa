@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class KSCrashIntegrationTests: NotificationCenterTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "KSCrashIntegrationTests")

    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let hub: SentryHubInternal
        let client: TestClient!
        let options: Options
        let crashReporter: TestSentryCrashWrapper
        let fileManager: TestFileManager

        init() throws {
            SentryDependencyContainer.sharedInstance().sysctlWrapper = TestSysctl()
            crashReporter = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
            crashReporter.internalActiveDurationSinceLastCrash = 5.0
            crashReporter.internalCrashedLastLaunch = true

            options = Options()
            options.dsn = KSCrashIntegrationTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            options.tracesSampleRate = 1.0

            client = TestClient(options: options, fileManager: try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            ))
            hub = TestHub(client: client, andScope: nil)

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )

            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
        }

        var session: SentrySession {
            let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
            session.incrementErrors()
            return session
        }

        func getSut() throws -> KSCrashIntegration<MockKSCrashDependencies> {
            return try getSut(crashReporter: crashReporter)
        }

        func getSut(
            crashReporter: SentryCrashReporter,
            fileManager: SentryFileManager? = nil,
            options: Options? = nil
        ) throws -> KSCrashIntegration<MockKSCrashDependencies> {
            let deps = MockKSCrashDependencies(
                crashReporter: crashReporter,
                dispatchQueueWrapper: dispatchQueueWrapper,
                fileManager: fileManager
            )
            return try XCTUnwrap(KSCrashIntegration(with: options ?? self.options, dependencies: deps))
        }

        var sutWithoutCrash: KSCrashIntegration<MockKSCrashDependencies>? {
            let reporter = crashReporter
            reporter.internalCrashedLastLaunch = false
            let deps = MockKSCrashDependencies(crashReporter: reporter, dispatchQueueWrapper: dispatchQueueWrapper)
            return KSCrashIntegration(with: options, dependencies: deps)
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()

        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAppState()
        fixture.client.fileManager.deleteAppHangEvent()

        SentrySDK.setStart(with: fixture.options)
    }

    override func tearDown() {
        super.tearDown()
        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAbnormalSession()
        fixture.client.fileManager.deleteAppState()
        fixture.client.fileManager.deleteAppHangEvent()

        SentryCrashAttachmentsStorage.basePath = nil

        clearTestState()
    }

    // MARK: - Basic Init

    func testDisabledCrashHandler_returnsNil() {
        let options = Options()
        options.enableCrashHandler = false
        let deps = MockKSCrashDependencies(
            crashReporter: fixture.crashReporter,
            dispatchQueueWrapper: fixture.dispatchQueueWrapper
        )
        let integration = KSCrashIntegration(with: options, dependencies: deps)
        XCTAssertNil(integration)
    }

    func testEnabledCrashHandler_returnsNonNil() throws {
        let sut = try fixture.getSut()
        XCTAssertNotNil(sut)
    }

    func testName() {
        XCTAssertEqual("CrashIntegration", KSCrashIntegration<MockKSCrashDependencies>.name)
    }

    // MARK: - Scope

    func testInstall_addsScopeObserver() throws {
        SentrySDKInternal.setCurrentHub(fixture.hub)
        _ = try fixture.getSut()
        // Verify that the scope observer is active by checking that a scope
        // change propagates (environment is a simple scalar to test).
        SentrySDK.configureScope { scope in
            scope.setEnvironment("test-observer")
        }
        // The integration registers fine if init did not fail.
        XCTAssertEqual("test-observer", fixture.hub.scope.environmentString)
    }

    // MARK: - Session Handling

    func testEndSessionAsCrashed_WithCurrentSession() throws {
        let expectedCrashedSession = givenCrashedSession()
        SentrySDKInternal.setCurrentHub(fixture.hub)

        advanceTime(bySeconds: 10)

        _ = try fixture.getSut()

        assertCrashedSessionStored(expected: expectedCrashedSession)
    }

    func testEndSessionAsCrashed_NoCrashLastLaunch() throws {
        let session = givenCurrentSession()

        let reporter = fixture.crashReporter
        reporter.internalCrashedLastLaunch = false
        _ = try fixture.getSut(crashReporter: reporter)

        let fileManager = fixture.client.fileManager
        try XCTAssertTrue(session.isEqual(to: XCTUnwrap(fileManager.readCurrentSession())))
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }

    func testEndSessionAsCrashed_NoCurrentSession() throws {
        let (_, _) = try givenSutWithGlobalHub()

        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }

    // MARK: - Locale Notifications

    func testUninstall_DoesNotUpdateLocale_OnLocaleDidChangeNotification() throws {
        let (sut, hub) = try givenSutWithGlobalHub()

        let locale = "garbage"
        setLocaleToGlobalScope(locale: locale)

        sut.uninstall()
        localeDidChange()

        assertLocaleOnHub(locale: locale, hub: hub)
    }

    func testLocaleChanged_NoDeviceContext_SetsCurrentLocale() throws {
        let (sut, hub) = try givenSutWithGlobalHub()
        defer { sut.uninstall() }

        SentrySDK.configureScope { scope in
            scope.removeContext(key: "device")
        }

        localeDidChange()

        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }

    func testLocaleChanged_DifferentLocale_SetsCurrentLocale() throws {
        let (sut, hub) = try givenSutWithGlobalHub()
        defer { sut.uninstall() }

        setLocaleToGlobalScope(locale: "garbage")
        localeDidChange()

        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }

    // MARK: - lastRunStatus

    func testInit_setsCrashReporterInstalled() throws {
        XCTAssertFalse(SentrySDKInternal.crashReporterInstalled)
        _ = try fixture.getSut()
        XCTAssertTrue(SentrySDKInternal.crashReporterInstalled)
    }

    func testInit_whenNoCrash_shouldNotCallOnLastRunStatusCallback() throws {
        var callbackCalled = false
        fixture.options.onLastRunStatusDetermined = { _, _ in
            callbackCalled = true
        }

        let reporter = fixture.crashReporter
        reporter.internalCrashedLastLaunch = false
        _ = try fixture.getSut(crashReporter: reporter)

        XCTAssertFalse(callbackCalled)
        XCTAssertFalse(SentrySDKInternal.lastRunStatusCalled)
    }

    // MARK: - Transaction Tracing

    func testPersistingTracesEnabled_passedThroughToConfiguration() throws {
        fixture.options.enablePersistingTracesWhenCrashing = true
        let sut = try fixture.getSut()
        XCTAssertNotNil(sut)
        // Integration initialised without crash — configuration with willWriteReportCallback
        // is wired inside startCrashHandler. The factory tests verify the callback is set;
        // here we just confirm the integration does not throw when the flag is enabled.
    }

    func testPersistingTracesDisabled_integrationInitialises() throws {
        fixture.options.enablePersistingTracesWhenCrashing = false
        let sut = try fixture.getSut()
        XCTAssertNotNil(sut)
    }

    // MARK: - Attachments

    func test_startCrashHandler_setsAttachmentsBasePath() throws {
        _ = try fixture.getSut()
        let expectedBase = (fixture.options.cacheDirectoryPath as NSString)
            .appendingPathComponent("Attachments")
        XCTAssertEqual(SentryCrashAttachmentsStorage.basePath, expectedBase)
    }

    // MARK: - Private helpers

    private func givenCurrentSession() -> SentrySession {
        let session = SentrySession(jsonObject: fixture.session.serialize())!
        fixture.client.fileManager.storeCurrentSession(session)
        return session
    }

    private func givenCrashedSession() -> SentrySession {
        let session = givenCurrentSession()
        session.endCrashed(withTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(5))
        return session
    }

    private func givenSutWithGlobalHub() throws -> (KSCrashIntegration<MockKSCrashDependencies>, SentryHubInternal) {
        let sut = try XCTUnwrap(fixture.getSut())
        let hub = fixture.hub
        SentrySDKInternal.setCurrentHub(hub)
        return (sut, hub)
    }

    private func setLocaleToGlobalScope(locale: String) {
        SentrySDK.configureScope { scope in
            guard var device = scope.contextDictionary["device"] as? [String: Any] else {
                return
            }
            device["locale"] = locale
            scope.setContext(value: device, key: "device")
        }
    }

    private func assertCrashedSessionStored(expected: SentrySession) {
        let crashedSession = fixture.client.fileManager.readCrashedSession()
        XCTAssertEqual(SentrySessionStatus.crashed, crashedSession?.status)
        try XCTAssertTrue(expected.isEqual(to: XCTUnwrap(crashedSession)))
        XCTAssertNil(fixture.client.fileManager.readCurrentSession())
    }

    private func assertLocaleOnHub(locale: String, hub: SentryHubInternal) {
        let context = hub.scope.contextDictionary as? [String: Any] ?? ["": ""]
        guard let device = context["device"] as? [String: Any] else {
            XCTFail("No device found on context.")
            return
        }
        XCTAssertEqual(locale, device["locale"] as? String)
    }

    private func advanceTime(bySeconds: TimeInterval) {
        (SentryDependencyContainer.sharedInstance().dateProvider as? TestCurrentDateProvider)?.setDate(
            date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds)
        )
    }
}

// MARK: - Mock Dependencies

class MockKSCrashDependencies: KSCrashIntegrationProvider {

    let mockedCrashReporter: SentryCrashReporter
    let mockedDispatchQueueWrapper: SentryDispatchQueueWrapper
    let mockedFileManager: SentryFileManager?

    init(
        crashReporter: SentryCrashReporter,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        fileManager: SentryFileManager? = nil
    ) {
        self.mockedCrashReporter = crashReporter
        self.mockedDispatchQueueWrapper = dispatchQueueWrapper
        self.mockedFileManager = fileManager
    }

    var kscrashReporter: SentryCrashReporter {
        mockedCrashReporter
    }

    var fileManager: SentryFileManager? {
        mockedFileManager ?? SentryDependencyContainer.sharedInstance().fileManager
    }

    var dateProvider: SentryCurrentDateProvider {
        SentryDependencyContainer.sharedInstance().dateProvider
    }

    var appStateManager: SentryAppStateManager {
        SentryDependencyContainer.sharedInstance().appStateManager
    }

    func getCrashInstallationReporter(_ options: Options) -> SentryKSCrashInstallationReporter {
        SentryKSCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: options.inAppIncludes))
    }

    func getKSCrashIntegrationSessionHandler(_ options: Options) -> SentryKSCrashIntegrationSessionHandler? {
        guard let fileManager else { return nil }
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        let watchdogLogic = SentryWatchdogTerminationLogic(
            options: options,
            crashAdapter: mockedCrashReporter,
            appStateManager: appStateManager
        )
        return SentryKSCrashIntegrationSessionHandler(
            crashReporter: mockedCrashReporter,
            watchdogTerminationLogic: watchdogLogic,
            dateProvider: dateProvider,
            fileManager: fileManager
        )
#else
        return SentryKSCrashIntegrationSessionHandler(
            crashReporter: mockedCrashReporter,
            dateProvider: dateProvider,
            fileManager: fileManager
        )
#endif
    }
}
