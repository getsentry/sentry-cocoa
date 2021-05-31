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
        let crashAdapter = TestSentryCrashWrapper()
        let appStateManager: SentryAppStateManager
        
        let appStartDuration: TimeInterval = 0.4
        
        init() {
            options = Options()
            options.dsn = SentryAppStartTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
            
            appStateManager = SentryAppStateManager(options: options, crashAdapter: crashAdapter, fileManager: fileManager, currentDateProvider: currentDate, sysctl: sysctl)
        }
        
        var sut: SentryAppStartTracker {
            return SentryAppStartTracker(options: options, currentDateProvider: currentDate, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), appStateManager: appStateManager, sysctl: sysctl)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTracker!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        
        let appStart = fixture.currentDate.date().addingTimeInterval(-fixture.appStartDuration)
        fixture.sysctl.setProcessStartTimestamp(value: appStart)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.fileManager.deleteAllFolders()
        SentrySDK.appStartMeasurement = nil
    }
    
    func testFirstStart_IsColdStart() {
        startApp()
        
        assertIsColdStart()
    }
    
    func testSecondStart_AfterSystemReboot_IsColdStart() {
        let previousBootTime = fixture.currentDate.date().addingTimeInterval(-1)
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: previousBootTime)
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertIsColdStart()
    }
    
    func testSecondStart_SystemNotRebooted_IsWarmStart() {
        givenSystemNotRebooted()
        
        startApp()
        
        assertIsWarmStart()
    }
    
    func testAppUpgrade_IsColdStart() {
        let appState = SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: fixture.currentDate.date())
        givenPreviousAppState(appState: appState)
        
        startApp()
        
        assertIsColdStart()
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
        givenPreviousAppState(appState: TestData.appState)
        
        startApp()
        sendAppMeasurement()
        terminateApp()
        
        givenSystemNotRebooted()
        startApp()
        
        assertIsWarmStart()
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
    
    private func givenPreviousAppState(appState: SentryAppState) {
        fixture.fileManager.store(appState)
    }
    
    private func givenSystemNotRebooted() {
        let systemBootTimestamp = fixture.currentDate.date()
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, isDebugging: false, systemBootTimestamp: systemBootTimestamp)
        givenPreviousAppState(appState: appState)
    }
    
    private func startApp() {
        sut = fixture.sut
        sut.start()
        goToForeground()
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
        SentrySDK.appStartMeasurement = nil
    }
    
    private func assertIsColdStart() {
        XCTAssertNotNil(SentrySDK.appStartMeasurement)
        XCTAssertEqual(fixture.appStartDuration, SentrySDK.appStartMeasurement?.duration)
        XCTAssertEqual(SentryAppStartType.cold, SentrySDK.appStartMeasurement?.type)
    }
    
    private func assertIsWarmStart() {
        XCTAssertNotNil(SentrySDK.appStartMeasurement)
        XCTAssertEqual(fixture.appStartDuration, SentrySDK.appStartMeasurement?.duration)
        XCTAssertEqual(SentryAppStartType.warm, SentrySDK.appStartMeasurement?.type)
    }
    
    private func assertNoAppStartUp() {
        XCTAssertNil(SentrySDK.appStartMeasurement)
    }
}

#endif
