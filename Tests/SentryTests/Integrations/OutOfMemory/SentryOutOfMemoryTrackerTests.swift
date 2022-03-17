import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryOutOfMemoryTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")
    private static let dsn = TestConstants.dsn(username: "SentryOutOfMemoryTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        init() {
            options = Options()
            options.dsn = SentryOutOfMemoryTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: crashWrapper, andCurrentDateProvider: currentDate)
            SentrySDK.setCurrentHub(hub)
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }
        
        func getSut() -> SentryOutOfMemoryTracker {
            return getSut(fileManager: self.fileManager)
        }
        
        func getSut(fileManager: SentryFileManager) -> SentryOutOfMemoryTracker {
            let appStateManager = SentryAppStateManager(options: options, crashWrapper: crashWrapper, fileManager: fileManager, currentDateProvider: currentDate, sysctl: sysctl)
            let logic = SentryOutOfMemoryLogic(options: options, crashAdapter: crashWrapper, appStateManager: appStateManager)
            return SentryOutOfMemoryTracker(options: options, outOfMemoryLogic: logic, appStateManager: appStateManager, dispatchQueueWrapper: dispatchQueue, fileManager: fileManager)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryOutOfMemoryTracker!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.fileManager.deleteAllFolders()
        
        clearTestState()
    }

    func testStart_StoresAppState() {
        sut.start()
        
        let actual = fixture.fileManager.readAppState()
        
        let appState = SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: fixture.sysctl.systemBootTimestamp)
        
        XCTAssertEqual(appState, actual)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testGoToForeground_SetsIsActive() {
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
    
    func testAppWasInForeground_OOM() {
        sut.start()
        goToForeground()

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
    
    func testAppOOM_WithOnlyHybridSdkDidBecomeActive() {
        sut.start()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_Foreground_And_HybridSdkDidBecomeActive() {
        sut.start()
        goToForeground()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_HybridSdkDidBecomeActive_and_Foreground() {
        sut.start()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        goToForeground()
        
        sut.start()
        assertOOMEventSent()
    }
    
    func testTerminateApp_RunsOnMainThread() {
        sut.start()
        
        TestNotificationCenter.willTerminate()
        
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
        
        TestNotificationCenter.hybridSdkDidBecomeActive()
        goToForeground()
        terminateApp()
        
        XCTAssertEqual(1, fileManager.readAppStateInvocations.count)
    }
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.fileManager.store(appState)
    }
    
    private func update(appState: (SentryAppState) -> Void) {
        if let currentAppState = fixture.fileManager.readAppState() {
            appState(currentAppState)
            fixture.fileManager.store(currentAppState)
        }
    }
    
    private func goToForeground() {
        TestNotificationCenter.willEnterForeground()
        TestNotificationCenter.didBecomeActive()
    }
    
    private func goToBackground() {
        TestNotificationCenter.willResignActive()
        TestNotificationCenter.didEnterBackground()
    }
    
    private func terminateApp() {
        TestNotificationCenter.willTerminate()
        sut.stop()
    }
    
    private func assertOOMEventSent() {
        XCTAssertEqual(1, fixture.client.captureCrashEventInvocations.count)
        let crashEvent = fixture.client.captureCrashEventInvocations.first?.event
        
        XCTAssertEqual(SentryLevel.fatal, crashEvent?.level)
        XCTAssertEqual([], crashEvent?.breadcrumbs)
        
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
