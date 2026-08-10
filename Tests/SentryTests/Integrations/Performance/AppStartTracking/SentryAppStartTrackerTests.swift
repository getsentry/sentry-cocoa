@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

// swiftlint:disable file_length type_body_length
#if os(iOS) || os(tvOS)

class TestAppStartInfoProvider: AppStartInfoProvider {
    var mockRuntimeInitTimestamp: Date
    var mockIsActivePrewarm: Bool

    init(runtimeInitTimestamp: Date = Date(), isActivePrewarm: Bool = false) {
        self.mockRuntimeInitTimestamp = runtimeInitTimestamp
        self.mockIsActivePrewarm = isActivePrewarm
    }

    func runtimeInitTimestamp() -> Date {
        return mockRuntimeInitTimestamp
    }

    func isActivePrewarm() -> Bool {
        return mockIsActivePrewarm
    }
}

class SentryAppStartTrackerTests: NotificationCenterTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryAppStartTrackerTests")

    private class Fixture {

        let options: Options
        let currentDate = TestCurrentDateProvider()
        let sysctl = TestSysctl()
        let fileManager: SentryFileManager
        let crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        let appStateManager: SentryAppStateManager
        var displayLinkWrapper = TestDisplayLinkWrapper()
        let framesTracker: SentryFramesTracker
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        var enablePreWarmedAppStartTracing = true
        #if SDK_V10
        let enableStandaloneAppStartTracing = true
        #else
        var enableStandaloneAppStartTracing = false
        #endif
        var appStartInfoProvider: TestAppStartInfoProvider

        let appStartDuration: TimeInterval = 0.4
        var runtimeInitTimestamp: Date
        var moduleInitializationTimestamp: Date
        var sdkStartTimestamp: Date
        var didFinishLaunchingTimestamp: Date
        
        init() throws {
            options = Options()
            options.dsn = SentryAppStartTrackerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName

            SentryDependencyContainer.sharedInstance().dateProvider = currentDate

            fileManager = try XCTUnwrap(SentryFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueue
            ))

            SentryDependencyContainer.sharedInstance().sysctlWrapper = sysctl
            SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
            appStateManager = SentryAppStateManager(
                releaseName: options.releaseName,
                crashWrapper: crashWrapper,
                fileManager: fileManager,
                sysctlWrapper: sysctl
            )

            framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: currentDate, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                                                notificationCenter: TestNSNotificationCenterWrapper(), delayedFramesTracker: TestDelayedWrapper(keepDelayedFramesDuration: 0, dateProvider: currentDate))
            framesTracker.start()

            runtimeInitTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.2)
            moduleInitializationTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.1)
            sdkStartTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.1)
            SentrySDKInternal.startTimestamp = sdkStartTimestamp

            didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.2)

            appStartInfoProvider = TestAppStartInfoProvider(
                runtimeInitTimestamp: runtimeInitTimestamp,
                isActivePrewarm: false
            )
        }
        
        var sut: SentryAppStartTracker {
            let sut = SentryAppStartTracker(
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                appStateManager: appStateManager,
                framesTracker: framesTracker,
                enablePreWarmedAppStartTracing: enablePreWarmedAppStartTracing,
                enableStandaloneAppStartTracing: enableStandaloneAppStartTracing,
                dateProvider: SentryDependencyContainer.sharedInstance().dateProvider,
                sysctlWrapper: SentryDependencyContainer.sharedInstance().sysctlWrapper,
                appStartInfoProvider: appStartInfoProvider,
                extendedAppLaunchManager: SentryDependencyContainer.sharedInstance().extendedAppLaunchManager
            )
            return sut
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTracker!

    #if SDK_V10
    private var standaloneHub: TestHub!
    #endif

    override func setUpWithError() throws {
        try super.setUpWithError()

        fixture = try Fixture()

        fixture.sysctl.setProcessStartTimestamp(value: SentryDependencyContainer.sharedInstance().dateProvider.date())

        #if SDK_V10
        fixture.options.tracesSampleRate = 1
        let client = TestClient(options: fixture.options)
        standaloneHub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(standaloneHub)
        #endif
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
        fixture.fileManager.deleteAllFolders()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testFirstStart_IsColdStart() {
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }
    
    func testRemovesFramesTrackerListener() throws {
        #if SDK_V10
        throw XCTSkip("Standalone mode does not use the frames tracker listener")
        #else
        startApp(callDisplayLink: true)

        advanceTime(bySeconds: 0.05)
        fixture.displayLinkWrapper.normalFrame()

        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }
    
    func testSecondStart_AfterSystemReboot_IsColdStart() {
        let previousBootTime = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-1)
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: previousBootTime)
        store(appState: appState)
        
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }

    func testSecondStart_SystemNotRebooted_IsWarmStart() {
        givenSystemNotRebooted()

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
        #endif
    }

    // Test for situation described in https://github.com/getsentry/sentry-cocoa/issues/2376
    func testSecondStart_SystemNotRebooted_OOM_disabled_IsWarmStart() {
        givenSystemNotRebooted()

        fixture.options.enableWatchdogTerminationTracking = false

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(callDisplayLink: true)
        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        standaloneHub.capturedTransactionsWithScope.reset()
        #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
        #endif

        fixture.fileManager.moveAppStateToPreviousAppState()
        fixture.framesTracker.resetFrames()
        startApp(callDisplayLink: true)
        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
        #endif
    }
    
    func testAppUpgrade_IsColdStart() {
        let appState = SentryAppState(releaseName: "0.9.0", osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date())
        store(appState: appState)
        
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }

    func testAppWasInBackground_NoAppStartUp() {
        store(appState: TestData.appState)
        
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
        
        let appState = SentryAppState(releaseName: "1.0.0", osVersion: "14.4.1", vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date())
        store(appState: appState)

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
        #endif
    }

    /**
     * Test if the user changes the time of his phone and the previous boot time is in the future.
     */
    func testAppLaunches_PreviousBootTimeInFuture_NoAppStartUp() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(1))
        store(appState: appState)

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp()
        
        assertNoAppStartUp()
    }
    
    func testAppLaunches_OSPrewarmedProcess_AppStartUpShortened() {
        fixture.appStartInfoProvider.mockIsActivePrewarm = true
        givenSystemNotRebooted()

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(processStartTimeStamp: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-60 * 60 * 4), callDisplayLink: true)
#if os(iOS)
    #if SDK_V10
        assertStandaloneTransaction(type: .warm)
    #else
        assertValidStart(type: .warm, expectedDuration: 0.35, preWarmed: true)
    #endif
#else
        assertNoAppStartUp()
#endif
    }
    
    func testAppLaunches_OSPrewarmedProcess_FeatureDisabled_NoAppStartUp() {
        fixture.enablePreWarmedAppStartTracing = false
        fixture.appStartInfoProvider.mockIsActivePrewarm = true
        givenSystemNotRebooted()

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(callDisplayLink: true)
#if os(iOS)
        assertNoAppStartUp()
#else
    #if SDK_V10
        assertStandaloneTransaction(type: .warm)
    #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
    #endif
#endif
    }
    
    func testAppLaunches_OSStopsAtLaterAppLaunchStep_NoAppStartUp() {
        fixture.appStartInfoProvider.mockIsActivePrewarm = true
        givenSystemNotRebooted()
        givenModuleInitializationTimestamp(timestamp: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-200))

        let currentDate = SentryDependencyContainer.sharedInstance().dateProvider.date()
        startApp(
            processStartTimeStamp: currentDate.addingTimeInterval(-200.5),
            runtimeInitTimestamp: currentDate.addingTimeInterval(-200.4),
            moduleInitializationTimestamp: currentDate.addingTimeInterval(-200)
        )

        assertNoAppStartUp()
    }

    func testAppLaunches_WrongEnvValue_AppStartUp() {
        fixture.appStartInfoProvider.mockIsActivePrewarm = false
        givenSystemNotRebooted()

        fixture.fileManager.moveAppStateToPreviousAppState()
        startApp(callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        #else
        assertValidStart(type: .warm, expectedDuration: 0.45)
        #endif
    }

    func testAppLaunches_MaximumAppStartDuration_NoAppStart() throws {
        #if SDK_V10
        throw XCTSkip("Standalone mode does not apply maximum app start duration limit")
        #else
        let processStartTime = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-180)
        startApp(processStartTimeStamp: processStartTime, callDisplayLink: true)

        assertNoAppStartUp()
        #endif
    }

    func testAppLaunches_OSAlmostPrewarmedProcess_AppStartUp() {
        let processStartTime = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-179)
        startApp(processStartTimeStamp: processStartTime, callDisplayLink: true)

        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidStart(type: .cold, expectedDuration: 179.45)
        #endif
    }
    
    func testAppLaunchesBackgroundTask_NoAppStartUp() {
        sut = fixture.sut
        sut.start()
        
        didEnterBackground()
        
        assertNoAppStartUp()
    }
    
    func testAppLaunchesBackgroundTask_GoesToForeground_NoAppStartUp() {
        sut = fixture.sut
        sut.start()
        didEnterBackground()
        
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
        
        willEnterForeground()
        
        givenDidFinishLaunchingTimestamp()
        
        didFinishLaunching()
        
        sut.start()
        
        advanceTime(bySeconds: 0.1)
        uiWindowDidBecomeVisible()
        didBecomeActive()
        
        advanceTime(bySeconds: 0.05)
        fixture.currentDate.driftTimeForEveryRead = true
        fixture.displayLinkWrapper.normalFrame()
        fixture.currentDate.driftTimeForEveryRead = false
        
        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }

    func testHybridSDKs_ColdStart() {
        hybridAppStart()

        #if SDK_V10
        assertStandaloneTransaction(type: .cold)
        #else
        assertValidHybridStart(type: .cold)
        #endif
    }

    func testHybridSDKs_SecondStart_SystemNotRebooted_IsWarmStart() {
        givenSystemNotRebooted()

        fixture.fileManager.moveAppStateToPreviousAppState()
        hybridAppStart()

        #if SDK_V10
        assertStandaloneTransaction(type: .warm)
        #else
        assertValidHybridStart(type: .warm)
        #endif
    }

    func testBackgroundLaunch_whenStandalone_shouldClearAppStartTraceId() {
        #if !SDK_V10
        fixture.enableStandaloneAppStartTracing = true
        #endif
        sut = fixture.sut
        sut.start()

        XCTAssertNotNil(SentryAppStartMeasurementProvider.appStartTraceId())

        didEnterBackground()

        assertNoAppStartUp()
        XCTAssertNil(SentryAppStartMeasurementProvider.appStartTraceId())
    }

    func testLongDuration_whenStandalone_shouldNotDropAppStart() throws {
        fixture.options.tracesSampleRate = 1
        let client = TestClient(options: fixture.options)
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)

        #if !SDK_V10
        fixture.enableStandaloneAppStartTracing = true
        #endif
        let processStartTime = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(-180)
        startApp(processStartTimeStamp: processStartTime, callDisplayLink: true)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start")
    }

    func testStart_whenStandaloneAppStartTracingAndSDKNotEnabled_shouldDropAppStart() {
        #if SDK_V10
        SentrySDKInternal.setCurrentHub(TestHub(client: nil, andScope: nil))
        #else
        fixture.enableStandaloneAppStartTracing = true
        #endif
        startApp(callDisplayLink: true)

        // The standalone handler guards on SentrySDK.isEnabled. Since the SDK is not
        // fully started in this test, the measurement is dropped.
        assertNoAppStartUp()
    }

    func testStart_whenStandaloneAppStartTracingDisabled_shouldSetAppStartMeasurement() throws {
        #if SDK_V10
        throw XCTSkip("Standalone app start tracing is always enabled in v10")
        #else
        fixture.enableStandaloneAppStartTracing = false
        startApp(callDisplayLink: true)

        assertValidStart(type: .cold, expectedDuration: 0.45)
        #endif
    }

    func testStart_whenStandaloneAppStartTracingEnabled_shouldCaptureTransaction() throws {
        fixture.options.tracesSampleRate = 1
        let client = TestClient(options: fixture.options)
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)

        #if !SDK_V10
        fixture.enableStandaloneAppStartTracing = true
        #endif
        startApp(callDisplayLink: true)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start")

        // The global static must not be set — standalone bypasses it.
        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())

        // Verify the transaction contains app start child spans (standalone = no grouping span,
        // no "Initial Frame Render" since standalone ends at didFinishLaunching).
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        XCTAssertEqual(spans.count, 4)

        let descriptions = spans.compactMap { $0["description"] as? String }
        XCTAssertTrue(descriptions.contains("Pre Runtime Init"))
        XCTAssertTrue(descriptions.contains("Application Init"))

        // Verify the app start vitals are set as span data.
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        XCTAssertNotNil(extra["app.vitals.start.cold.value"])
    }

    private func store(appState: SentryAppState) {
        fixture.fileManager.store(appState)
    }
    
    private func givenSystemNotRebooted() {
        let systemBootTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        fixture.sysctl.setProcessStartTimestamp(value: SentryDependencyContainer.sharedInstance().dateProvider.date())
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: TestData.someUUID, isDebugging: false, systemBootTimestamp: systemBootTimestamp)
        store(appState: appState)
    }
    
    private func givenProcessStartTimestamp(processStartTimestamp: Date? = nil) {
        fixture.sysctl.setProcessStartTimestamp(value: processStartTimestamp ?? SentryDependencyContainer.sharedInstance().dateProvider.date())
    }
    
    private func givenRuntimeInitTimestamp(sut: SentryAppStartTracker, timestamp: Date? = nil) {
        fixture.runtimeInitTimestamp = timestamp ?? SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.2)
        fixture.appStartInfoProvider.mockRuntimeInitTimestamp = fixture.runtimeInitTimestamp
    }
    
    private func givenModuleInitializationTimestamp(timestamp: Date? = nil) {
        fixture.sysctl.setModuleInitializationTimestamp(value: timestamp ?? fixture.moduleInitializationTimestamp)
    }

    private func givenDidFinishLaunchingTimestamp() {
        fixture.didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(0.3)
        advanceTime(bySeconds: 0.3)
    }
    
    private func startApp(processStartTimeStamp: Date? = nil, runtimeInitTimestamp: Date? = nil, moduleInitializationTimestamp: Date? = nil, callDisplayLink: Bool = false) {
        givenProcessStartTimestamp(processStartTimestamp: processStartTimeStamp)
        
        sut = fixture.sut
        givenRuntimeInitTimestamp(sut: sut, timestamp: runtimeInitTimestamp)
        givenModuleInitializationTimestamp(timestamp: moduleInitializationTimestamp)
        sut.start()
        
        willEnterForeground()
        
        givenDidFinishLaunchingTimestamp()
        
        didFinishLaunching()
        advanceTime(bySeconds: 0.1)
        uiWindowDidBecomeVisible()
        didBecomeActive()
        
        if callDisplayLink {
            advanceTime(bySeconds: 0.05)
            fixture.currentDate.driftTimeForEveryRead = true
            fixture.displayLinkWrapper.normalFrame()
            fixture.currentDate.driftTimeForEveryRead = false
        }
    }
    
    private func hybridAppStart() {
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true

        givenProcessStartTimestamp()

        advanceTime(bySeconds: 0.2)
        fixture.runtimeInitTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        fixture.appStartInfoProvider.mockRuntimeInitTimestamp = fixture.runtimeInitTimestamp

        willEnterForeground()

        advanceTime(bySeconds: 0.3)
        fixture.didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()

        sut = fixture.sut
        givenModuleInitializationTimestamp()

        didFinishLaunching()

        advanceTime(bySeconds: 0.1)
        uiWindowDidBecomeVisible()
        didBecomeActive()

        // The Hybrid SDKs call start after all the notifications are posted,
        // because they init the SentrySDK when the hybrid engine is ready.
        sut.start()
    }
    
    internal override func terminateApp() {
        super.terminateApp()
        sut.stop()
    }
    
    /**
     * We assume a class reads the app measurement, sends it with a transaction to Sentry and sets it to nil.
     */
    private func sendAppMeasurement() {
        SentrySDKInternal.setAppStartMeasurement(nil)
    }
    
    private func assertValidStart(type: SentryAppStartType, expectedDuration: TimeInterval? = nil, preWarmed: Bool = false) {
        guard let appStartMeasurement = SentrySDKInternal.getAppStartMeasurement() else {
            XCTFail("AppStartMeasurement must not be nil")
            return
        }
        
        XCTAssertEqual(type.rawValue, appStartMeasurement.type.rawValue)
        
        let expectedAppStartDuration = expectedDuration ?? fixture.appStartDuration
        let actualAppStartDuration = appStartMeasurement.duration
        XCTAssertEqual(actualAppStartDuration, expectedAppStartDuration, accuracy: 0.0001)
        
        if preWarmed {
            XCTAssertEqual(fixture.moduleInitializationTimestamp, appStartMeasurement.appStartTimestamp)
        } else {
            XCTAssertEqual(fixture.sysctl.processStartTimestamp, appStartMeasurement.appStartTimestamp)
        }

        XCTAssertEqual(appStartMeasurement.moduleInitializationTimestamp, fixture.sysctl.moduleInitializationTimestamp)
        XCTAssertEqual(appStartMeasurement.runtimeInitTimestamp, fixture.runtimeInitTimestamp)
        
        XCTAssertEqual(appStartMeasurement.sdkStartTimestamp, fixture.sdkStartTimestamp)
        XCTAssertEqual(appStartMeasurement.didFinishLaunchingTimestamp, fixture.didFinishLaunchingTimestamp)
        XCTAssertEqual(appStartMeasurement.isPreWarmed, preWarmed)
    }
    
    private func assertValidHybridStart(type: SentryAppStartType) {
        guard let appStartMeasurement = SentrySDKInternal.getAppStartMeasurement() else {
            XCTFail("AppStartMeasurement must not be nil")
            return
        }
        
        XCTAssertEqual(type.rawValue, appStartMeasurement.type.rawValue)
        
        let actualAppStartDuration = appStartMeasurement.duration
        XCTAssertEqual(0.0, actualAppStartDuration, accuracy: 0.0001)
        
        XCTAssertEqual(fixture.sysctl.processStartTimestamp, appStartMeasurement.appStartTimestamp)
        XCTAssertEqual(fixture.runtimeInitTimestamp, appStartMeasurement.runtimeInitTimestamp)
        XCTAssertEqual(Date(timeIntervalSinceReferenceDate: 0), appStartMeasurement.didFinishLaunchingTimestamp)
    }
    
    private func assertNoAppStartUp() {
        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())
    }

    #if SDK_V10
    private func assertStandaloneTransaction(type: SentryAppStartType, file: StaticString = #filePath, line: UInt = #line) {
        guard let serialized = standaloneHub.capturedTransactionsWithScope.invocations.first?.transaction else {
            XCTFail("Standalone app start transaction must be captured", file: file, line: line)
            return
        }
        XCTAssertEqual(serialized["transaction"] as? String, "App Start", file: file, line: line)
        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement(), "Global static must not be set in standalone mode", file: file, line: line)

        let extra = serialized["extra"] as? [String: Any]
        let typeKey = type == .cold ? "app.vitals.start.cold.value" : "app.vitals.start.warm.value"
        XCTAssertNotNil(extra?[typeKey], "Expected \(typeKey) in transaction extra", file: file, line: line)
    }
    #endif
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}

#endif
