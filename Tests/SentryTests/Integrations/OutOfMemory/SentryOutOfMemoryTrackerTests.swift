import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryOutOfMemoryTrackerTests: NotificationCenterTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")
    private static let dsn = TestConstants.dsn(username: "SentryOutOfMemoryTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let client: TestClient
        let crashWrapper: TestSentryCrashWrapper
        lazy var mockFileManager = try! TestFileManager(options: options, andCurrentDateProvider: currentDate)
        lazy var realFileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate, dispatchQueueWrapper: dispatchQueue)
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        init() {
            options = Options()
            options.maxBreadcrumbs = 2
            options.dsn = SentryOutOfMemoryTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: crashWrapper, andCurrentDateProvider: currentDate)
            SentrySDK.setCurrentHub(hub)
        }
        
        func getSut(usingRealFileManager: Bool) -> SentryOutOfMemoryTracker {
            return getSut(fileManager: usingRealFileManager ? realFileManager : mockFileManager)
        }
        
        func getSut(fileManager: SentryFileManager) -> SentryOutOfMemoryTracker {
            let appStateManager = SentryAppStateManager(options: options, crashWrapper: crashWrapper, fileManager: fileManager, currentDateProvider: currentDate, sysctl: sysctl, dispatchQueueWrapper: self.dispatchQueue)
            let logic = SentryOutOfMemoryLogic(options: options, crashAdapter: crashWrapper, appStateManager: appStateManager)
            return SentryOutOfMemoryTracker(options: options, outOfMemoryLogic: logic, appStateManager: appStateManager, dispatchQueueWrapper: dispatchQueue, fileManager: fileManager)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryOutOfMemoryTracker!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        sut = fixture.getSut(usingRealFileManager: false)
        SentrySDK.startInvocations = 1
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.client.fileManager.deleteAllFolders()
        
        clearTestState()
    }

    func testStart_StoresAppState() {
        sut = fixture.getSut(usingRealFileManager: true)

        XCTAssertNil(fixture.mockFileManager.readAppState())

        sut.start()
        
        let actual = fixture.mockFileManager.readAppState()
        
        let appState = SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.sysctl.systemBootTimestamp)
        
        XCTAssertEqual(appState, actual)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testGoToForeground_SetsIsActive() {
        sut = fixture.getSut(usingRealFileManager: true)

        sut.start()
        
        goToForeground()
        
        XCTAssertTrue(fixture.mockFileManager.readAppState()?.isActive ?? false)
        
        goToBackground()
        
        XCTAssertFalse(fixture.mockFileManager.readAppState()?.isActive ?? true)
        XCTAssertEqual(3, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testGoToForeground_WhenAppStateNil_NothingIsStored() {
        sut.start()
        fixture.mockFileManager.deleteAppState()
        goToForeground()
        
        XCTAssertNil(fixture.mockFileManager.readAppState())
    }

    func testDifferentAppVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.currentDate.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testDifferentOSVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: "1.0.0", vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.currentDate.date()))
        
        sut.start()
        
        assertNoOOMSent()
    }
    
    func testDifferentVendorId_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: "1.0.0", vendorId: "0987654321", isDebugging: false, systemBootTimestamp: fixture.currentDate.date()))
        
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
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.currentDate.date())
        givenPreviousAppState(appState: appState)
        fixture.crashWrapper.internalCrashedLastLaunch = true
        
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
    
    func testAppWasInForeground_OOM() {
        sut = fixture.getSut(usingRealFileManager: true)

        sut.start()
        goToForeground()

        fixture.mockFileManager.moveAppStateToPreviousAppState()
        sut.start()
        assertOOMEventSent()
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

    func testAppOOM_WithBreadcrumbs() {
        sut = fixture.getSut(usingRealFileManager: true)

        let breadcrumb = TestData.crumb

        let sentryOutOfMemoryScopeObserver = SentryOutOfMemoryScopeObserver(maxBreadcrumbs: Int(fixture.options.maxBreadcrumbs), fileManager: fixture.mockFileManager)

        for _ in 0..<3 {
            sentryOutOfMemoryScopeObserver.addSerializedBreadcrumb(breadcrumb.serialize())
        }

        sut.start()
        goToForeground()

        fixture.mockFileManager.moveAppStateToPreviousAppState()
        fixture.mockFileManager.moveBreadcrumbsToPreviousBreadcrumbs()
        sut.start()
        assertOOMEventSent(expectedBreadcrumbs: 2)

        let crashEvent = fixture.client.captureCrashEventInvocations.first?.event
        XCTAssertEqual(crashEvent?.timestamp, breadcrumb.timestamp)
    }

    func testAppOOM_WithOnlyHybridSdkDidBecomeActive() {
        sut = fixture.getSut(usingRealFileManager: true)

        sut.start()
        hybridSdkDidBecomeActive()

        fixture.mockFileManager.moveAppStateToPreviousAppState()
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_Foreground_And_HybridSdkDidBecomeActive() {
        sut = fixture.getSut(usingRealFileManager: true)

        sut.start()
        goToForeground()
        hybridSdkDidBecomeActive()

        fixture.mockFileManager.moveAppStateToPreviousAppState()
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_HybridSdkDidBecomeActive_and_Foreground() {
        sut = fixture.getSut(usingRealFileManager: true)
        
        sut.start()
        hybridSdkDidBecomeActive()
        goToForeground()

        fixture.mockFileManager.moveAppStateToPreviousAppState()
        sut.start()
        assertOOMEventSent()
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
        let fileManager = try TestFileManager(options: Options(), andCurrentDateProvider: TestCurrentDateProvider())
        sut = fixture.getSut(fileManager: fileManager)

        sut.start()
        sut.stop()
        
        hybridSdkDidBecomeActive()
        goToForeground()
        terminateApp()
        
        XCTAssertEqual(1, fileManager.readPreviousAppStateInvocations.count)
    }
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.mockFileManager.store(appState)
    }
    
    private func update(appState: (SentryAppState) -> Void) {
        if let currentAppState = fixture.mockFileManager.readAppState() {
            appState(currentAppState)
            fixture.mockFileManager.store(currentAppState)
        }
    }
    
    private func assertOOMEventSent(expectedBreadcrumbs: Int = 0) {
        XCTAssertEqual(1, fixture.client.captureCrashEventInvocations.count)
        let crashEvent = fixture.client.captureCrashEventInvocations.first?.event
        
        XCTAssertEqual(SentryLevel.fatal, crashEvent?.level)
        XCTAssertEqual(crashEvent?.breadcrumbs?.count, 0)
        XCTAssertEqual(crashEvent?.serializedBreadcrumbs?.count, expectedBreadcrumbs)
        
        XCTAssertEqual(1, crashEvent?.exceptions?.count)
        
        let exception = crashEvent?.exceptions?.first
        XCTAssertEqual("The OS most likely terminated your app because it overused RAM.", exception?.value)
        XCTAssertEqual("OutOfMemory", exception?.type)
        
        XCTAssertNotNil(exception?.mechanism)
        XCTAssertEqual(false, exception?.mechanism?.handled)
        XCTAssertEqual("out_of_memory", exception?.mechanism?.type)
    }

    private func assertNoOOMSent() {
        XCTAssertEqual(0, fixture.client.captureCrashEventInvocations.count)
    }
}

#endif
