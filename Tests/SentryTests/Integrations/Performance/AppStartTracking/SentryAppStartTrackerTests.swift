import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryAppStartTrackerTests")
    private static let dsn = TestConstants.dsn(username: "SentryAppStartTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let fileManager: SentryFileManager
        let crashAdapter = TestSentryCrashAdapter.sharedInstance()
        let appStateManager: SentryAppStateManager
        
        let appStartDuration: TimeInterval = 0.4
        var runtimeInitTimestamp: Date
        var didFinishLaunchingTimestamp: Date
        
        init() {
            options = Options()
            options.dsn = SentryAppStartTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
            
            appStateManager = SentryAppStateManager(options: options, crashAdapter: crashAdapter, fileManager: fileManager, currentDateProvider: currentDate, sysctl: sysctl)
            
            runtimeInitTimestamp = currentDate.date().addingTimeInterval(0.2)
            didFinishLaunchingTimestamp = currentDate.date().addingTimeInterval(0.3)
        }
        
        var sut: SentryAppStartTracker {
            let sut = SentryAppStartTracker(currentDateProvider: currentDate, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), appStateManager: appStateManager, sysctl: sysctl)
            return sut
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTracker!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        
        fixture.sysctl.setProcessStartTimestamp(value: fixture.currentDate.date())
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
    }
    
    func testFirstStart_IsColdStart() {
        startApp()
        
        assertValidStart(type: .cold)
    }
    
    func testSecondStart_AfterSystemReboot_IsColdStart() {
        let previousBootTime = fixture.currentDate.date().addingTimeInterval(-1)
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: previousBootTime)
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertValidStart(type: .cold)
    }
    
    func testSecondStart_SystemNotRebooted_IsWarmStart() {
        givenSystemNotRebooted()
        
        startApp()
        
        assertValidStart(type: .warm)
    }
    
    func testAppUpgrade_IsColdStart() {
        let appState = SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: fixture.currentDate.date())
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertValidStart(type: .cold)
    }
    
    func testAppWasInBackground_NoAppStartUp() {
        givenPreviousAppState(appState: TestData.appState)
        
        startApp()
        
        sendAppMeasurement()
        
        goToBackground()
        goToForeground()
        
        assertNoAppStartUp()
    }
    
    func testAppTerminates_LaunchesAgain_WarmAppStart() {
        startApp()
        sendAppMeasurement()
        terminateApp()
        
        let appState = SentryAppState(releaseName: "1.0.0", osVersion: "14.4.1", isDebugging: false, systemBootTimestamp: self.fixture.currentDate.date())
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertValidStart(type: .warm)
    }
    
    /**
     * Test if the user changes the time of his phone and the previous boot time is in the future.
     */
    func testAppLaunches_PreviousBootTimeInFuture_NoAppStartUp() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: fixture.currentDate.date().addingTimeInterval(1))
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertNoAppStartUp()
    }
    
    func testAppLaunchesBackgroundTask_NoAppStartUp() {
        sut = fixture.sut
        sut.start()
        
        TestNotificationCenter.didEnterBackground()
        
        assertNoAppStartUp()
    }
    
    func testAppLaunchesBackgroundTask_GoesToForeground_NoAppStartUp() {
        sut = fixture.sut
        sut.start()
        TestNotificationCenter.didEnterBackground()
        
        goToForeground()
        
        assertNoAppStartUp()
    }
    
    /**
     * Test for reproducing GH-1225
     * It can happen that the OS posts the didFinishLaunching notification before we register for it.
     */
    func testDidFinishLaunching_PostedBeforeStart() {
        givenProcessStartTimestamp()
        sut = fixture.sut
        givenRuntimeInitTimestamp(sut: sut)
        
        TestNotificationCenter.willEnterForeground()
        
        givenDidFinishLaunchingTimestamp()
        
        TestNotificationCenter.didFinishLaunching()
        
        sut.start()
        
        advanceTime(bySeconds: 0.1)
        TestNotificationCenter.uiWindowDidBecomeVisible()
        TestNotificationCenter.didBecomeActive()
        
        assertValidStart(type: .cold)
    }
    
    func testHybridSDKs_ColdStart() {
        hybridAppStart()
        
        assertValidHybridStart(type: .cold)
    }
    
    func testHybridSDKs_SecondStart_SystemNotRebooted_IsWarmStart() {
        givenSystemNotRebooted()
        
        hybridAppStart()
        
        assertValidHybridStart(type: .warm)
    }
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.fileManager.store(appState)
    }
    
    private func givenSystemNotRebooted() {
        let systemBootTimestamp = fixture.currentDate.date()
        fixture.sysctl.setProcessStartTimestamp(value: fixture.currentDate.date())
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: systemBootTimestamp)
        givenPreviousAppState(appState: appState)
    }
    
    private func givenProcessStartTimestamp() {
        fixture.sysctl.setProcessStartTimestamp(value: fixture.currentDate.date())
    }
    
    private func givenRuntimeInitTimestamp(sut: SentryAppStartTracker) {
        fixture.runtimeInitTimestamp = fixture.currentDate.date().addingTimeInterval(0.2)
        Dynamic(sut).setRuntimeInit(fixture.runtimeInitTimestamp)
    }
    
    private func givenDidFinishLaunchingTimestamp() {
        fixture.didFinishLaunchingTimestamp = fixture.currentDate.date().addingTimeInterval(0.3)
        advanceTime(bySeconds: 0.3)
    }
    
    private func startApp() {
        givenProcessStartTimestamp()
        
        sut = fixture.sut
        givenRuntimeInitTimestamp(sut: sut)
        sut.start()
        
        TestNotificationCenter.willEnterForeground()
        
        givenDidFinishLaunchingTimestamp()
        
        TestNotificationCenter.didFinishLaunching()
        advanceTime(bySeconds: 0.1)
        TestNotificationCenter.uiWindowDidBecomeVisible()
        TestNotificationCenter.didBecomeActive()
    }
    
    private func hybridAppStart() {
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        givenProcessStartTimestamp()
        
        advanceTime(bySeconds: 0.2)
        fixture.runtimeInitTimestamp = fixture.currentDate.date()
        
        TestNotificationCenter.willEnterForeground()
        
        advanceTime(bySeconds: 0.3)
        fixture.didFinishLaunchingTimestamp = fixture.currentDate.date()
        
        sut = fixture.sut
        Dynamic(sut).setRuntimeInit(fixture.runtimeInitTimestamp)
        
        TestNotificationCenter.didFinishLaunching()
        
        advanceTime(bySeconds: 0.1)
        TestNotificationCenter.uiWindowDidBecomeVisible()
        TestNotificationCenter.didBecomeActive()
        
        // The Hybrid SDKs call start after all the notifications are posted,
        // because they init the SentrySDK when the hybrid engine is ready.
        sut.start()
    }
    
    private func goToForeground() {
        TestNotificationCenter.willEnterForeground()
        TestNotificationCenter.uiWindowDidBecomeVisible()
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
    
    /**
     * We assume a class reads the app measurement, sends it with a transaction to Sentry and sets it to nil.
     */
    private func sendAppMeasurement() {
        SentrySDK.setAppStartMeasurement(nil)
    }

    private func assertValidStart(type: SentryAppStartType) {
        guard let appStartMeasurement = SentrySDK.getAppStartMeasurement() else {
            XCTFail("AppStartMeasurement must not be nil")
            return
        }
        
        XCTAssertEqual(type.rawValue, appStartMeasurement.type.rawValue)

        let expectedAppStartDuration = fixture.appStartDuration
        let actualAppStartDuration = appStartMeasurement.duration
        XCTAssertEqual(expectedAppStartDuration, actualAppStartDuration, accuracy: 0.000_1)

        XCTAssertEqual(fixture.sysctl.processStartTimestamp, appStartMeasurement.appStartTimestamp)
        XCTAssertEqual(fixture.runtimeInitTimestamp, appStartMeasurement.runtimeInitTimestamp)
        XCTAssertEqual(fixture.didFinishLaunchingTimestamp, appStartMeasurement.didFinishLaunchingTimestamp)
    }
    
    private func assertValidHybridStart(type: SentryAppStartType) {
        guard let appStartMeasurement = SentrySDK.getAppStartMeasurement() else {
            XCTFail("AppStartMeasurement must not be nil")
            return
        }
        
        XCTAssertEqual(type.rawValue, appStartMeasurement.type.rawValue)

        let actualAppStartDuration = appStartMeasurement.duration
        XCTAssertEqual(0.0, actualAppStartDuration, accuracy: 0.000_1)

        XCTAssertEqual(fixture.sysctl.processStartTimestamp, appStartMeasurement.appStartTimestamp)
        XCTAssertEqual(fixture.runtimeInitTimestamp, appStartMeasurement.runtimeInitTimestamp)
        XCTAssertEqual(Date(timeIntervalSinceReferenceDate: 0), appStartMeasurement.didFinishLaunchingTimestamp)
    }

    private func assertNoAppStartUp() {
        XCTAssertNil(SentrySDK.getAppStartMeasurement())
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: fixture.currentDate.date().addingTimeInterval(bySeconds))
    }
}

#endif
