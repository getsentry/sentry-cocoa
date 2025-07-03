@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if compiler(>=6.0)
@_spi(Private) extension SentryFileManager: @retroactive SentryFileManagerProtocol { }
#else
@_spi(Private) extension SentryFileManager: SentryFileManagerProtocol { }
#endif

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryWatchdogTerminationTrackerTests: NotificationCenterTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let dispatchQueue = TestSentryDispatchQueueWrapper()

        let breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor
        let attributesProcessor: SentryWatchdogTerminationAttributesProcessor
        let scopePersistentStore: SentryScopePersistentStore

        init() throws {
            SentryDependencyContainer.sharedInstance().sysctlWrapper = sysctl
            options = Options()
            options.maxBreadcrumbs = 2
            options.dsn = SentryWatchdogTerminationTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueue)

            breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: Int(options.maxBreadcrumbs), fileManager: fileManager)
            let backgroundQueueWrapper = TestSentryDispatchQueueWrapper()
            scopePersistentStore = try XCTUnwrap(SentryScopePersistentStore(fileManager: fileManager))
            attributesProcessor = SentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: backgroundQueueWrapper,
                scopePersistentStore: scopePersistentStore
            )

            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: crashWrapper, andDispatchQueue: SentryDispatchQueueWrapper())
            SentrySDK.setCurrentHub(hub)
        }
        
        func getSut() throws -> SentryWatchdogTerminationTracker {
            return try getSut(fileManager: fileManager )
        }
        
        func getSut(fileManager: SentryFileManager) throws -> SentryWatchdogTerminationTracker {
            let appStateManager = SentryAppStateManager(
                options: options,
                crashWrapper: crashWrapper,
                fileManager: fileManager,
                dispatchQueueWrapper: self.dispatchQueue,
                notificationCenterWrapper: SentryNSNotificationCenterWrapper()
            )
            let logic = SentryWatchdogTerminationLogic(
                options: options,
                crashAdapter: crashWrapper,
                appStateManager: appStateManager
            )
            let scopePersistentStore = try XCTUnwrap(SentryScopePersistentStore(
                fileManager: fileManager
            ))
            return SentryWatchdogTerminationTracker(
                options: options,
                watchdogTerminationLogic: logic,
                appStateManager: appStateManager,
                dispatchQueueWrapper: dispatchQueue,
                fileManager: fileManager,
                scopePersistentStore: scopePersistentStore
            )
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTracker!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        fixture = try Fixture()
        sut = try fixture.getSut()
        SentrySDK.startInvocations = 1
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.client.fileManager.deleteAllFolders()
        
        clearTestState()
    }

    func testStart_StoresAppState() throws {
        sut = try fixture.getSut()

        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        
        let actual = fixture.fileManager.readAppState()
        
        let appState = SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.sysctl.systemBootTimestamp)
        
        XCTAssertEqual(appState, actual)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testGoToForeground_SetsIsActive() throws {
        sut = try fixture.getSut()

        sut.start()
        
        goToForeground()
        
        XCTAssertTrue(fixture.fileManager.readAppState()?.isActive ?? false)
        
        goToBackground()
        
        XCTAssertFalse(fixture.fileManager.readAppState()?.isActive ?? true)
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testGoToForeground_WhenAppStateNil_NothingIsStored() {
        sut.start()
        fixture.fileManager.deleteAppState()
        goToForeground()
        
        XCTAssertNil(fixture.fileManager.readAppState())
    }

    func testDifferentAppVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testDifferentReleaseNameNil_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: nil, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testDifferentOSVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: "1.0.0", vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testDifferentVendorId_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: "1.0.0", vendorId: "0987654321", isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testIsDebugging_NoOOM() {
        fixture.crashWrapper.internalIsBeingTraced = true
        sut.start()
        
        goToForeground()
        goToBackground()
        terminateApp()
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testIsSimulatorBuild_NoOOM() {
        fixture.crashWrapper.internalIsSimulatorBuild = true
        sut.start()
        
        goToForeground()
        goToBackground()
        terminateApp()
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testTerminatedNormally_NoOOM() {
        sut.start()
        goToForeground()
        goToBackground()
        terminateApp()
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testCrashReport_NoOOM() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date())
        givenPreviousAppState(appState: appState)
        fixture.crashWrapper.internalCrashedLastLaunch = true
        
        sut.start()
        
        assertNoOOMSent()
    }

    func testSDKWasClosed_NoOOM() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date())
        appState.isSDKRunning = false

        givenPreviousAppState(appState: appState)
        sut.start()
        assertNoOOMSent()
    }

    func testAppWasInBackground_NoOOM() {
        sut.start()
        goToForeground()
        goToBackground()
        
        sut.stop()
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testSDKStartedTwice_NoOOM() {
        sut.start()
        goToForeground()

        SentrySDK.startInvocations = 2
        sut.start()
        assertNoOOMSent()
    }

    func testDifferentBootTime_NoOOM() throws {
        sut = try fixture.getSut()
        sut.start()
        let appState = SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.sysctl.systemBootTimestamp.addingTimeInterval(1))

        givenPreviousAppState(appState: appState)
        fixture.fileManager.moveAppStateToPreviousAppState()
        sut.start()
        assertNoOOMSent()
    }

    func testAppWasInForeground_OOM() throws {
        sut = try fixture.getSut()

        sut.start()
        goToForeground()

        fixture.fileManager.moveAppStateToPreviousAppState()
        sut.start()
        try assertOOMEventSent()
    }

    func testANR_NoOOM() {
        sut.start()
        goToForeground()
        
        update(appState: { appState in
            appState.isANROngoing = true
        })

        sut.start()
        assertNoOOMSent()
    }

    func testAppOOM_WithBreadcrumbs() throws {
        sut = try fixture.getSut()

        let breadcrumb = TestData.crumb
        let sentryWatchdogTerminationScopeObserver = SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: fixture.breadcrumbProcessor,
            attributesProcessor: fixture.attributesProcessor
        )

        for _ in 0..<3 {
            sentryWatchdogTerminationScopeObserver.addSerializedBreadcrumb(breadcrumb.serialize())
        }

        sut.start()
        goToForeground()

        fixture.fileManager.moveAppStateToPreviousAppState()
        fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
        sut.start()
        try assertOOMEventSent(expectedBreadcrumbs: 2)

        let fatalEvent = fixture.client.captureFatalEventInvocations.first?.event
        XCTAssertEqual(fatalEvent?.timestamp, breadcrumb.timestamp)
    }
    
    func testAppOOM_WithAttributes() throws {
        sut = try fixture.getSut()

        let sentryWatchdogTerminationScopeObserver = SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: fixture.breadcrumbProcessor,
            attributesProcessor: fixture.attributesProcessor
        )

        let testUser = TestData.user
        let extra = ["key": "value"] as [String: Any]
        let testContext = ["device": ["name": "iPhone"], "appData": ["version": "1.0.0"]] as [String: [String: Any]]
        let dist = "1.0.0"
        let env = "development"
        let tags = ["tag1": "value1", "tag2": "value2"]
        let traceContext = ["trace_id": "1234567890", "span_id": "1234567890"]
        sentryWatchdogTerminationScopeObserver.setUser(testUser)
        sentryWatchdogTerminationScopeObserver.setContext(testContext)
        sentryWatchdogTerminationScopeObserver.setDist(dist)
        sentryWatchdogTerminationScopeObserver.setEnvironment(env)
        sentryWatchdogTerminationScopeObserver.setTags(tags)
        sentryWatchdogTerminationScopeObserver.setExtras(extra)
        sentryWatchdogTerminationScopeObserver.setFingerprint(["fingerprint1", "fingerprint2"])

        sut.start()
        goToForeground()

        fixture.fileManager.moveAppStateToPreviousAppState()
        fixture.scopePersistentStore.moveAllCurrentStateToPreviousState()
        sut.start()

        let fatalEvent = fixture.client.captureFatalEventInvocations.first?.event

        // Verify all attributes are properly set on the event
        XCTAssertEqual(fatalEvent?.user?.userId, testUser.userId)
        XCTAssertEqual(fatalEvent?.user?.email, testUser.email)
        XCTAssertEqual(fatalEvent?.user?.username, testUser.username)
        XCTAssertEqual(fatalEvent?.user?.name, testUser.name)
        
        XCTAssertEqual(fatalEvent?.dist, dist)
        XCTAssertEqual(fatalEvent?.environment, env)
        XCTAssertEqual(fatalEvent?.tags, tags)

        XCTAssertEqual(NSDictionary(dictionary: fatalEvent?.extra ?? [:]), NSDictionary(dictionary: extra))
        XCTAssertEqual(fatalEvent?.fingerprint, ["fingerprint1", "fingerprint2"])

        // Verify context is properly set (including the app.in_foreground = true that's added by the tracker)
        let eventContext = fatalEvent?.context
        XCTAssertNotNil(eventContext)
        XCTAssertEqual(eventContext?["device"] as? [String: String], testContext["device"] as? [String: String])
        XCTAssertEqual(eventContext?["appData"] as? [String: String], testContext["appData"] as? [String: String])
    }

    func testAppOOM_WithOnlyHybridSdkDidBecomeActive() throws {
        sut = try fixture.getSut()

        sut.start()
        hybridSdkDidBecomeActive()

        fixture.fileManager.moveAppStateToPreviousAppState()
        sut.start()
        try assertOOMEventSent()
    }
    
    func testAppOOM_Foreground_And_HybridSdkDidBecomeActive() throws {
        sut = try fixture.getSut()

        sut.start()
        goToForeground()
        hybridSdkDidBecomeActive()

        fixture.fileManager.moveAppStateToPreviousAppState()
        sut.start()
        try assertOOMEventSent()
    }
    
    func testAppOOM_HybridSdkDidBecomeActive_and_Foreground() throws {
        sut = try fixture.getSut()
        
        sut.start()
        hybridSdkDidBecomeActive()
        goToForeground()

        fixture.fileManager.moveAppStateToPreviousAppState()
        sut.start()
        try assertOOMEventSent()
    }
    
    func testTerminateApp_RunsOnMainThread() {
        sut.start()
        
        willTerminate()
        
        // 1 for start
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testStartThenStop_NoOOM() {
        sut.start()
        goToForeground()
        sut.stop()

        sut.start()
     
        assertNoOOMSent()
    }
    
    func testStop_StopsObserving_NoMoreFileManagerInvocations() throws {
        let fileManager = try! TestFileManager(options: Options())
        sut = try fixture.getSut(fileManager: fileManager)

        sut.start()
        sut.stop()
        
        hybridSdkDidBecomeActive()
        goToForeground()
        terminateApp()
        
        XCTAssertEqual(1, fileManager.readPreviousAppStateInvocations.count)
    }
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.fileManager.store(appState)
        fixture.fileManager.moveAppStateToPreviousAppState()
    }
    
    private func update(appState: (SentryAppState) -> Void) {
        if let currentAppState = fixture.fileManager.readAppState() {
            appState(currentAppState)
            fixture.fileManager.store(currentAppState)
        }
    }
    
    private func assertOOMEventSent(expectedBreadcrumbs: Int = 0) throws {
        XCTAssertEqual(1, fixture.client.captureFatalEventInvocations.count)
        let fatalEvent = try XCTUnwrap(fixture.client.captureFatalEventInvocations.first?.event)

        XCTAssertEqual(SentryLevel.fatal, fatalEvent.level)
        XCTAssertEqual(fatalEvent.breadcrumbs?.count, 0)
        XCTAssertEqual(fatalEvent.serializedBreadcrumbs?.count, expectedBreadcrumbs)
        
        XCTAssertEqual(1, fatalEvent.exceptions?.count)
        
        let exception = fatalEvent.exceptions?.first
        XCTAssertEqual("The OS watchdog terminated your app, possibly because it overused RAM.", exception?.value)
        XCTAssertEqual("WatchdogTermination", exception?.type)
        
        XCTAssertNotNil(exception?.mechanism)
        XCTAssertEqual(false, exception?.mechanism?.handled)
        XCTAssertEqual("watchdog_termination", exception?.mechanism?.type)
        
        let appContext = try XCTUnwrap(fatalEvent.context?["app"] as? [String: Any])
        XCTAssertEqual(true, appContext["in_foreground"] as? Bool)
    }

    private func assertNoOOMSent() {
        XCTAssertEqual(0, fixture.client.captureFatalEventInvocations.count)
    }
}

#endif
