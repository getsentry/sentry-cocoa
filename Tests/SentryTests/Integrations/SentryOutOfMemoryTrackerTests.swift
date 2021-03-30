import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryOutOfMemoryTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")
    private static let dsn = TestConstants.dsn(username: "SentryOutOfMemoryTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let client: TestClient!
        let sentryCrash: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let crashWrapper = TestSentryCrashWrapper()
        
        init() {
            options = Options()
            options.dsn = SentryOutOfMemoryTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            client = TestClient(options: options)
            
            sentryCrash = TestSentryCrashWrapper()
            
            let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: self.sentryCrash)
            SentrySDK.setCurrentHub(hub)
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: TestCurrentDateProvider())
        }
        
        func getSut() -> SentryOutOfMemoryTracker {
            return SentryOutOfMemoryTracker(options: options, outOfMemoryLogic: SentryOutOfMemoryLogic(options: options, crashAdapter: self.crashWrapper), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
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
    }

    func testStart_StoresAppState() {
        sut.start()
        
        let actual = fixture.fileManager.readAppState()
        
        let appState = SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: UIDevice.current.systemVersion, isDebugging: false)
        
        XCTAssertEqual(appState, actual)
    }
    
    func testGoToForeground_SetsIsActive() {
        sut.start()
        
        goToForeground()
        
        XCTAssertTrue(fixture.fileManager.readAppState()?.isActive ?? false)
        
        goToBackground()
        
        XCTAssertFalse(fixture.fileManager.readAppState()?.isActive ?? true)
    }
    
    func testGoToForeground_WhenAppStateNil_NothingIsStored() {
        sut.start()
        fixture.fileManager.deleteAppState()
        goToForeground()
        
        XCTAssertNil(fixture.fileManager.readAppState())
    }

    func testDifferentAppVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, isDebugging: false))
        
        sut.start()
        
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testDifferentOSVersions_NoOOM() {
        givenPreviousAppState(appState: SentryAppState(releaseName: fixture.options.releaseName ?? "", osVersion: "1.0.0", isDebugging: false))
        
        sut.start()
        
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testIsDebugging_NoOOM() {
        fixture.crashWrapper.internalIsBeingTraced = true
        sut.start()
        
        goToForeground()
        goToBackground()
        terminateApp()
        
        sut.start()
        
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testTerminatedNormally_NoOOM() {
        sut.start()
        goToForeground()
        goToBackground()
        terminateApp()
        
        sut.start()
        
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testCrashReport_NoOOM() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false)
        givenPreviousAppState(appState: appState)
        fixture.crashWrapper.internalCrashedLastLaunch = true
        
        sut.start()
        
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testAppWasInBackground_NoOOM() {
        sut.start()
        goToForeground()
        goToBackground()
        
        sut.stop()
        
        sut.start()
        XCTAssertEqual(0, fixture.client.captureMessageWithScopeArguments.count)
    }
    
    func testAppWasInForeground_OOM() {
        sut.start()
        goToForeground()
        sut.stop()

        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_WithOnlyHybridSdkDidBecomeActive() {
        sut.start()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        sut.stop()
        
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_Foreground_And_HybridSdkDidBecomeActive() {
        sut.start()
        goToForeground()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        sut.stop()
        
        sut.start()
        assertOOMEventSent()
    }
    
    func testAppOOM_HybridSdkDidBecomeActive_and_Foreground() {
        sut.start()
        TestNotificationCenter.hybridSdkDidBecomeActive()
        goToForeground()
        sut.stop()
        
        sut.start()
        assertOOMEventSent()
    }
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.fileManager.store(appState)
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
        XCTAssertEqual(1, fixture.client.captureCrashEventArguments.count)
        let crashEvent = fixture.client.captureCrashEventArguments.first?.event
        
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
}

#endif
