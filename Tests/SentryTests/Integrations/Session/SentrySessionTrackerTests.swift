@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentrySessionTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let currentDateProvider = TestCurrentDateProvider()
        let client: TestClient!
        let sentryCrash: TestSentryCrashWrapper

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        let application: TestSentryUIApplication
        #else
        let application: TestSentryNSApplication
        #endif
        let notificationCenter = TestNSNotificationCenterWrapper()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        lazy var fileManager = try! SentryFileManager(options: options, dateProvider: currentDateProvider, dispatchQueueWrapper: dispatchQueue)
        
        init() {
            options = Options()
            options.dsn = SentrySessionTrackerTests.dsnAsString
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = 10_000
            options.environment = "debug"
            
            client = TestClient(options: options)
            
            sentryCrash = TestSentryCrashWrapper.sharedInstance()

            #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
            application = TestSentryUIApplication()
            application.applicationState = .inactive
            SentryDependencyContainer.sharedInstance().application = application
            #else
            application = TestSentryNSApplication()
            application.setIsActive(false)
            SentryDependencyContainer.sharedInstance().application = application
            #endif
        }
        
        func getSut() -> SessionTracker {
            return SessionTracker(
                options: options,
                application: application,
                dateProvider: currentDateProvider,
                notificationCenter: notificationCenter
            )
        }
        
        func setNewHubToSDK() {
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: self.sentryCrash, andDispatchQueue: SentryDispatchQueueWrapper())
            SentrySDKInternal.setCurrentHub(hub)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SessionTracker!
    
    override class func setUp() {
        super.setUp()
        clearTestState()
    }
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()

        SentryDependencyContainer.sharedInstance().dateProvider = fixture.currentDateProvider

        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteTimestampLastInForeground()

        fixture.setNewHubToSDK()

        sut = fixture.getSut()
    }
    
    override func tearDown() {
        abnormalStopSut()
        clearTestState()

        super.tearDown()
    }

    func testOnlyForeground() throws {
        // -- Arrange --
        startSutInAppDelegate()

        // -- Act --
        goToForeground()

        // -- Assert --
        try assertInitSessionSent()
        assertSessionStored()
    }
    
    func testOnlyHybridSdkDidBecomeActive() throws {
        // -- Arrange --
        // In this test case the application state is unknown for the hybrid SDK.
        sut.start()

        // -- Act --
        hybridSdkDidBecomeActive()

        // -- Assert --
        try assertInitSessionSent()
        assertSessionStored()
    }
    
    func testForeground_And_HybridSdkDidBecomeActive() throws {
        // -- Arrange --
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        hybridSdkDidBecomeActive()

        // -- Assert --
        try assertInitSessionSent()
        assertSessionStored()
    }
    
    func testHybridSdkDidBecomeActive_and_Foreground() throws {
        // -- Arrange --
        sut.start()

        // -- Act --
        hybridSdkDidBecomeActive()
        goToForeground()

        // -- Assert --
        try assertInitSessionSent()
        assertSessionStored()
    }
    
    func testForeground_Background_TrackingIntervalNotReached() throws {
        // -- Arrange --
        startSutInAppDelegate()
        let sessionStartTimestamp = fixture.currentDateProvider.date()

        // -- Act --
        goToForeground()
        advanceTime(bySeconds: 11)

        goToBackground(forSeconds: 9)

        // -- Assert --
        try assertSessionInitSent(sessionStarted: sessionStartTimestamp)
    }
    
    func testForeground_Background_TrackingIntervalReached() {
        // -- Arrange --
        startSutInAppDelegate()
        let sessionStartTimestamp = fixture.currentDateProvider.date()

        // -- Act --
        goToForeground()
        advanceTime(bySeconds: 1)
        
        goToBackground(forSeconds: 9)
        // Session not sent yet, because the app needs to be in the background for a threshold time
        assertSessionsSent(count: 1)

        // Advance the time to meet the threshold
        advanceTime(bySeconds: 1)
        goToBackground(forSeconds: 10)

        // -- Assert --
        assertEndSessionSent(started: sessionStartTimestamp, duration: 11)
    }
    
    func testCrashInForeground_LaunchInForeground() throws {
        // -- Arrange --
        crashInForeground()
        try assertAppLaunchSendsCrashedSession()

        // -- Act --
        goToForeground()

        // -- Assert --
        assertSessionsSent(count: 3)
        try assertInitSessionSent()
    }
    
    func testCrashInForeground_LaunchInBackground() throws {
        // -- Arrange --
        crashInForeground()
        try assertAppLaunchSendsCrashedSession()

        // -- Act --
        goToBackground()

        // -- Assert --
        // only two sessions. First is the init, second is the crashed one,
        // but no extra init is sent.
        assertSessionsSent(count: 2)
        assertNoInitSessionSent()
    }
    
    func testCrashInBackground_LaunchInForeground() throws {
        // -- Arrange --
        crashInBackground()
        assertNoSessionSent()

        // -- Act & Assert --
        sut = fixture.getSut()
        startSutInAppDelegate()
        assertNoSessionSent()

        goToForeground()
        try assertInitSessionSent()
    }
    
    func testCrashInBackground_LaunchInBackground() {
        crashInBackground()
        assertNoSessionSent()
        
        sut = fixture.getSut()
        sut.start()
        
        assertNoSessionSent()
        assertNoInitSessionSent()
    }
    
    func testKillAppWithoutNotificationsAndNoCrash_EndsWithAbnormalSession() {
        // -- Arrange --
        let sessionStartTimestamp = fixture.currentDateProvider.date()
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        goToBackground(forSeconds: 2)
        advanceTime(bySeconds: 2)
        // This is not a crash but an abnormal end.
        abnormalStopSut()

        advanceTime(bySeconds: 1)

        sut = fixture.getSut()
        fixture.setNewHubToSDK()
        startSutInAppDelegate()

        // -- Assert --
        assertSessionSent(started: sessionStartTimestamp, duration: 0, status: SentrySessionStatus.abnormal)
    }
    
    func testTerminateWithoutCallingTerminateNotification() {
        // -- Arrange --
        let sessionStartTimestamp = fixture.currentDateProvider.date()
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        advanceTime(bySeconds: 5)
        goToBackground()
        // This is not a crash but an abnormal end.
        abnormalStopSut()

        advanceTime(bySeconds: 1)

        sut = fixture.getSut()
        fixture.setNewHubToSDK()
        startSutInAppDelegate()

        // -- Assert --
        assertSessionSent(started: sessionStartTimestamp, duration: 5, status: SentrySessionStatus.exited)
    }
    
    func testForegroundWithError() {
        // -- Arrange --
        let sessionStartTimestamp = fixture.currentDateProvider.date()
        startSutInAppDelegate()
        goToForeground()

        // -- Act --
        advanceTime(bySeconds: 1)
        captureError()
        advanceTime(bySeconds: 1)

        goToBackground()
        captureError()
        advanceTime(bySeconds: 10)
        goToForeground()

        // -- Assert --
        assertEndSessionSent(started: sessionStartTimestamp, duration: 2, errors: 2)
    }
    
    func testAppNotRunning_LaunchBackgroundTask() {
        // -- Act --
        launchBackgroundTaskAppNotRunning()

        // -- Assert --
        assertSessionNotStored()
        assertLastInForegroundIsNil()
        assertNoInitSessionSent()
        assertNoSessionSent()
    }
    
    func testAppRunning_LaunchBackgroundTask_UserOpensApp() {
        let sessionStarted = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 1)
        goToBackground()
        
        // Background task is launched
        advanceTime(bySeconds: 30)
        
        // user opens app
        goToForeground()
        assertEndSessionSent(started: sessionStarted, duration: 1)
    }
    
    func testAppRunning_LaunchBackgroundTaskImmediately_UserResumesApp() throws {
        let sessionStarted = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 1)
        goToBackground()
        
        // Background task is launched
        advanceTime(bySeconds: 2)
        
        // user opens app
        goToForeground()
        try assertSessionInitSent(sessionStarted: sessionStarted)
        assertSessionsSent(count: 1)
    }
    
    func testAppNotRunning_LaunchBackgroundTask_UserOpensApp() throws {
        // -- Arrange --
        launchBackgroundTaskAppNotRunning()
        advanceTime(bySeconds: 10)

        // -- Act --
        // user opens app
        let sessionStarted = fixture.currentDateProvider.date()
        goToForeground()
        try assertInitSessionSent()

        advanceTime(bySeconds: 1)
        
        goToBackground(forSeconds: 10)

        // -- Assert --
        assertEndSessionSent(started: sessionStarted, duration: 1)
    }

    func testForeground_Background_Terminate_LaunchAgain() throws {
        // -- Arrange --
        let sessionStartTime = fixture.currentDateProvider.date()
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        advanceTime(bySeconds: 1)
        goToBackground()

        advanceTime(bySeconds: 10)
        terminateApp()
        assertEndSessionSent(started: sessionStartTime, duration: 1)
        abnormalStopSut()

        advanceTime(bySeconds: 1)

        // Launch the app again
        fixture.setNewHubToSDK()

        sut = fixture.getSut()

        startSutInAppDelegate()
        goToForeground()

        // -- Assert --
        try assertInitSessionSent()
    }
    
    func testAppNotRunning_LaunchFromBackground_Terminate() {
        // -- Arrange --
        launchBackgroundTaskAppNotRunning()

        // -- Act --
        terminateApp()

        // -- Assert --
        assertNoSessionSent()
    }
    
    func testAppRunningInForeground_LaunchFromBackground_Terminate() {
        // -- Arrange --
        let startTime = fixture.currentDateProvider.date()
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        advanceTime(bySeconds: 2)
        goToBackground()
        
        terminateApp()

        // -- Assert --
        assertEndSessionSent(started: startTime, duration: 2)
    }
    
    func testForeground_Background_Foreground_NoSessionToEnd() throws {
        // -- Arrange --
        startSutInAppDelegate()

        // -- Act --
        goToForeground()
        goToBackground()
        advanceTime(bySeconds: 10)
        
        fixture.setNewHubToSDK()
        goToForeground()

        // -- Assert --
        try assertInitSessionSent()
        assertSessionsSent(count: 2)
    }
    
    func testStart_AddsObservers() throws {
        // -- Act --
        startSutInAppDelegate()

        // -- Assert --
        let invocations = fixture.notificationCenter.addObserverWithObjectInvocations
        let notificationNames = try invocations.invocations.map { try XCTUnwrap($0.name) }
        
        assertNotificationNames(notificationNames)
    }
    
    func testStop_RemovesObservers() throws {
        // -- Act --
        stopSut()

        // -- Assert --
        let invocations = fixture.notificationCenter.removeObserverWithNameAndObjectInvocations
        let notificationNames = try invocations.invocations.map { try XCTUnwrap($0.name) }
        
        assertNotificationNames(notificationNames)
    }

    func testForegroundBeforeStart_shoudStartSession() throws {
        // -- Arrange --
        goToForeground()

        // Pre-condition: No session should be sent yet
        assertNoSessionSent()

        // -- Act --
        sut.start()

        // -- Assert --
        XCTAssertEqual(fixture.client.captureSessionInvocations.invocations.count, 1)
        let startSessionEvent = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.element(at: 0))
        XCTAssertEqual(startSessionEvent.status, SentrySessionStatus.ok)
    }

    func testRestartInForeground_shouldStartNewSession() throws {
        // -- Arrange --
        startSutInAppDelegate()
        goToForeground()

        // -- Act --
        XCTAssertEqual(fixture.client.captureSessionInvocations.invocations.count, 1)
        var event = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.element(at: 0))
        XCTAssertEqual(event.status, SentrySessionStatus.ok)

        stopSut()

        XCTAssertEqual(fixture.client.captureSessionInvocations.invocations.count, 2)
        event = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.element(at: 1))
        XCTAssertEqual(event.status, SentrySessionStatus.exited)

        sut.start()

        // -- Assert --
        XCTAssertEqual(fixture.client.captureSessionInvocations.invocations.count, 3)
        event = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.element(at: 2))
        XCTAssertEqual(event.status, SentrySessionStatus.ok)
    }

    func testForeground_ThenHybridSdkNotification_ShouldDebounceSessionStart() throws {
        // -- Arrange --
        startSutInAppDelegate()
        let sessionStartTimestamp = fixture.currentDateProvider.date()

        // -- Act --
        // First, the app goes to foreground (starts a session)
        goToForeground()
        
        // Then immediately, the hybrid SDK posts its notification
        // This should be debounced and not start a new session
        postHybridSdkDidBecomeActiveNotification()

        // -- Assert --
        // Should only have one session (the init session), not two
        assertSessionsSent(count: 1)
        try assertSessionInitSent(sessionStarted: sessionStartTimestamp)
        assertSessionStored()
    }
    
    func testHybridSdkNotification_ThenForeground_ShouldDebounceSessionStart() throws {
        // -- Arrange --
        startSutInAppDelegate()
        let sessionStartTimestamp = fixture.currentDateProvider.date()

        // -- Act --
        // First, the hybrid SDK posts its notification (starts a session)
        postHybridSdkDidBecomeActiveNotification()
        
        // Then immediately, the app goes to foreground
        // This should be debounced and not start a new session
        goToForeground()

        // -- Assert --
        // Should only have one session (the init session), not two
        assertSessionsSent(count: 1)
        try assertSessionInitSent(sessionStarted: sessionStartTimestamp)
        assertSessionStored()
    }

    // MARK: - Helpers

    private func startSutInAppDelegate() {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // The Sentry SDK should be initialized in the `UIAppDelegate.didFinishLaunchingWithOptions`
        // At this point the application state is `inactive`, because the app just launched but did not
        // become the active app yet.
        //
        // This can be observed by viewing the application state in `UIAppDelegate.didFinishLaunchingWithOptions`.
        fixture.application.applicationState = .inactive
        #else
        // The Sentry SDK should be initialized in the `NSApplicationDelegate.applicationDidFinishLaunching`
        // At this point the app is not active yet.
        //
        // This can be observed by checking `NSApplication.shared.isActive` in `NSApplicationDelegate.applicationDidFinishLaunching`.
        fixture.application.setIsActive(false)
        #endif
        sut.start()
    }

    private func stopSut() {
        sut.stop()
        // After stopping the session tracker, we need to set a new hub to the SDK.
        fixture.setNewHubToSDK()
    }

    private func abnormalStopSut() {

        // We remove the observers, to ensure future notifications are not handled.
        sut.removeObservers()

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // When the app stops, the app state is `inactive`.
        // This can be observed by viewing the application state in `UIAppDelegate.applicationDidEnterBackground`.
        fixture.application.applicationState = .inactive
        #else
        // When the app crashes, the app state is `inactive`.
        //
        // This can not be observed in the view life cycle methods and is an assumption until proven otherwise.
        // macOS does not have a `applicationDidEnterBackground` method, so we can't observe the app state.
        fixture.application.setIsActive(false)
        #endif
    }

    private func crashSut() {
        sut.removeObservers()
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // When the app stops, the app state is `inactive`.
        //
        // This can be observed by viewing the application state in `UIAppDelegate.applicationDidEnterBackground`.
        fixture.application.applicationState = .inactive
        #else
        // When the app crashes, the app state is `inactive`.
        //
        // This can not be observed in the view life cycle methods and is an assumption until proven otherwise.
        // macOS does not have a `applicationDidEnterBackground` method, so we can't observe the app state.
        fixture.application.setIsActive(false)
        #endif
        fixture.sentryCrash.internalCrashedLastLaunch = true
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
    
    private func goToForeground() {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // When the app becomes active, the app state is `active`.
        // This can be observed by viewing the application state in `UIAppDelegate.applicationDidBecomeActive`.
        fixture.application.applicationState = .active
        #else
        // When the app becomes active, the app state is `active`.
        // This can be observed by viewing the application state in `NSApplicationDelegate.applicationDidBecomeActive`.
        fixture.application.setIsActive(true)
        #endif
        fixture.notificationCenter
            .post(
                Notification(
                    name: CrossPlatformApplication.didBecomeActiveNotification,
                    object: nil,
                    userInfo: nil
                )
            )
    }
    
    private func goToBackground() {
        // Before an app goes to background, it is still active and will resign from being active.
        willResignActive()
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // It is expected that the app state is background when the didEnterBackground is called
        fixture.application.applicationState = .background
        fixture.notificationCenter
           .post(
               Notification(
                  name: UIApplication.didEnterBackgroundNotification,
                   object: nil,
                   userInfo: nil
               )
           )
        #else
        // When the app becomes active, the app state is `active`.
        //
        // This can be observed by viewing the application state in `NSAppDelegate.applicationDidResignActive`.
        fixture.application.setIsActive(false)
        #endif
    }
    
    private func willResignActive() {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // When the app is about to resign being active, it is still active.
        //
        // This can be observed by viewing the application state in `UIAppDelegate.applicationWillResignActive`.
        fixture.application.applicationState = .active
        #else
        // When the app becomes active, the app state is `active`.
        //
        // This can be observed by viewing the application state in `NSAppDelegate.applicationWillResignActive`.
        fixture.application.setIsActive(true)
        #endif
        fixture.notificationCenter
            .post(
                Notification(
                    name: CrossPlatformApplication.willResignActiveNotification,
                    object: nil,
                    userInfo: nil
                )
            )
    }
    
    private func hybridSdkDidBecomeActive() {
        // When an app did become active, it is in the active state.
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        fixture.application.applicationState = .active
        #else
        fixture.application.setIsActive(true)
        #endif
        fixture.notificationCenter
            .post(
                Notification(
                    name: CrossPlatformApplication.didBecomeActiveNotification,
                    object: nil,
                    userInfo: nil
                )
            )
    }
    
    private func goToBackground(forSeconds: TimeInterval) {
        goToBackground()
        advanceTime(bySeconds: forSeconds)
        goToForeground()
    }
    
    private  func willTerminate() {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        // When terminating an app, it will first move to the background and then terminate.
        //
        // This can be observed by viewing the application state in `UIAppDelegate.applicationWillTerminate`.
        fixture.application.applicationState = .background
        #else
        // When terminating an app, it will first move to the background and then terminate.
        //
        // This can be observed by viewing the application state in `NSApplicationDelegate.applicationWillTerminate`.
        //
        // Important: According to the documentation, this method isn't called during sudden termination of an app.
        fixture.application.setIsActive(false)
        #endif
        fixture.notificationCenter
            .post(
                Notification(
                    name: CrossPlatformApplication.willTerminateNotification,
                    object: nil,
                    userInfo: nil
                )
            )
    }
    
    private func terminateApp() {
        willTerminate()
        abnormalStopSut()
    }
    
    private func launchBackgroundTaskAppNotRunning() {
        sut.removeObservers()

        fixture.setNewHubToSDK()
        sut = fixture.getSut()
        
        startSutInAppDelegate()
    }
    
    private func captureError() {
        SentrySDK.capture(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"]))
    }
    
    private func crashInForeground() {
        startSutInAppDelegate()
        goToForeground()
        crashSut()
    }
    
    private func crashInBackground() {
        startSutInAppDelegate()
        goToBackground()
        crashSut()
    }

    // MARK: - Assertion Helpers

    private func assertSessionNotStored(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(fixture.fileManager.readCurrentSession(), file: file, line: line)
    }
    
    private func assertSessionStored(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(fixture.fileManager.readCurrentSession(), file: file, line: line)
    }
    
    private func assertNoSessionSent(file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(0, fixture.client.captureSessionInvocations.count, file: file, line: line)
    }
    
    private func assertEndSessionSent(started: Date, duration: NSNumber, errors: UInt = 0) {
        
        // the end session is the second but last, because the sdk sends an session
        // init after sending the end of the session.
        let endSessionIndex = fixture.client.captureSessionInvocations.count - 2
        
        guard fixture.client.captureSessionInvocations.invocations.indices.contains(endSessionIndex) else {
            return XCTFail("Can't find EndSession.")
        }
        let session = fixture.client.captureSessionInvocations.invocations[endSessionIndex]
        XCTAssertFalse(session.flagInit?.boolValue ?? false)
        XCTAssertEqual(started, session.started)
        XCTAssertEqual(SentrySessionStatus.exited.description, session.status.description)
        XCTAssertEqual(errors, session.errors)
        XCTAssertEqual(started.addingTimeInterval(TimeInterval(truncating: duration)), session.timestamp)
        XCTAssertEqual(duration, session.duration)
        assertSessionFields(session: session)
    }
    
    private func assertSessionSent(started: Date, duration: NSNumber, status: SentrySessionStatus) {
        let endSessionIndex = fixture.client.captureSessionInvocations.count - 1

        guard fixture.client.captureSessionInvocations.invocations.indices.contains(endSessionIndex) else {
            return XCTFail("Can't find session.")
        }
        let session = fixture.client.captureSessionInvocations.invocations[endSessionIndex]
        assertSession(session: session, started: started, status: status, duration: duration)
    }
    
    private func assertSession(session: SentrySession, started: Date, status: SentrySessionStatus, duration: NSNumber) {
        XCTAssertFalse(session.flagInit?.boolValue ?? false)
        XCTAssertEqual(started, session.started)
        XCTAssertEqual(status.description, session.status.description)
        XCTAssertEqual(0, session.errors)
        XCTAssertEqual(started.addingTimeInterval(TimeInterval(truncating: duration)), session.timestamp)
        XCTAssertEqual(duration, session.duration)
        assertSessionFields(session: session)
    }

    private func assertInitSessionSent() throws {
        try assertSessionInitSent(sessionStarted: fixture.currentDateProvider.date())
    }

    private func assertSessionInitSent(sessionStarted: Date) throws {
        let session = try XCTUnwrap(fixture.client.captureSessionInvocations.last)
        XCTAssertTrue(session.flagInit?.boolValue ?? false)
        XCTAssertEqual(sessionStarted, session.started)
        XCTAssertEqual(SentrySessionStatus.ok.description, session.status.description)
        XCTAssertEqual(0, session.errors)
        XCTAssertNil(session.timestamp)
        XCTAssertNil(session.duration)
        assertSessionFields(session: session)
    }

    private func assertSessionFields(session: SentrySession) {
        XCTAssertNotNil(session.sessionId)
        XCTAssertNotNil(session.distinctId)
        XCTAssertEqual(fixture.options.environment, session.environment)
        XCTAssertNil(session.user)
    }
    
    private func assertNoInitSessionSent(file: StaticString = #file, line: UInt = #line) {
        let eventWithSessions = fixture.client.captureFatalEventWithSessionInvocations.invocations.map({ triple in triple.session })
        let errorWithSessions = fixture.client.captureErrorWithSessionInvocations.invocations.map({ triple in triple.session })
        let exceptionWithSessions = fixture.client.captureExceptionWithSessionInvocations.invocations.map({ triple in triple.session })
        
        var sessions = fixture.client.captureSessionInvocations.invocations + eventWithSessions + errorWithSessions + exceptionWithSessions
        
        sessions.sort { first, second in return first!.started < second!.started }
        
        if let session = sessions.last {
            XCTAssertFalse(session?.flagInit?.boolValue ?? false, file: file, line: line)
        }
    }
    
    private func assertSessionsSent(count: Int, file: StaticString = #file, line: UInt = #line) {
        let eventWithSessions = fixture.client.captureFatalEventWithSessionInvocations.count
        let errorWithSessions = fixture.client.captureErrorWithSessionInvocations.count
        let exceptionWithSessions = fixture.client.captureExceptionWithSessionInvocations.count
        let sessions = fixture.client.captureSessionInvocations.count
        
        let sessionsSent = eventWithSessions + errorWithSessions + exceptionWithSessions + sessions
        
        XCTAssertEqual(count, sessionsSent, file: file, line: line)
    }

    private func assertLastInForegroundIsNil(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(fixture.fileManager.readTimestampLastInForeground(), file: file, line: line)
    }
    
    private func assertLastInForegroundStored(file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.fileManager.readTimestampLastInForeground(), file: file, line: line)
    }
    
    private func assertAppLaunchSendsCrashedSession() throws {
        fixture.setNewHubToSDK()
        sut = fixture.getSut()
        let sessionStartTime = fixture.currentDateProvider.date()
        
        // SentryCrashIntegration stores the crashed session to the disk. We emulate
        // the result here.
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
        crashedSession.environment = fixture.options.environment
        advanceTime(bySeconds: 5)
        crashedSession.endCrashed(withTimestamp: fixture.currentDateProvider.date())
        fixture.fileManager.storeCrashedSession(crashedSession)
        
        startSutInAppDelegate()
        SentrySDKInternal.captureFatalEvent(Event())
        
        let session = try XCTUnwrap(fixture.client.captureFatalEventWithSessionInvocations.last?.session)
        assertSession(session: session, started: sessionStartTime, status: SentrySessionStatus.crashed, duration: 5)
    }
    
    private func assertNotificationNames(_ notificationNames: [NSNotification.Name]) {
        XCTAssertEqual(4, notificationNames.count)
        
        XCTAssertEqual([
            CrossPlatformApplication.didBecomeActiveNotification,
            NSNotification.Name(rawValue: SentryHybridSdkDidBecomeActiveNotificationName),
            CrossPlatformApplication.willResignActiveNotification,
            CrossPlatformApplication.willTerminateNotification
        ], notificationNames)
    }

    private func postHybridSdkDidBecomeActiveNotification() {
        // When the hybrid SDK posts this notification, the app should be in active state
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        fixture.application.applicationState = .active
        #else
        fixture.application.setIsActive(true)
        #endif
        fixture.notificationCenter
            .post(
                Notification(
                    name: NSNotification.Name(rawValue: SentryHybridSdkDidBecomeActiveNotificationName),
                    object: nil,
                    userInfo: nil
                )
            )
    }

#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
    private class TestSentryUIApplication: SentryUIApplication {
        init() {
            super.init(notificationCenterWrapper: TestNSNotificationCenterWrapper(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        }

        private var _underlyingAppState: UIApplication.State = .active
        override var applicationState: UIApplication.State {
            get { _underlyingAppState }
            set { _underlyingAppState = newValue }
        }

        override func isActive() -> Bool {
            return applicationState == .active
        }
    }
#else
    private class TestSentryNSApplication: SentryNSApplication {
        private var _underlyingIsActive = true
        func setIsActive(_ isActive: Bool) {
            _underlyingIsActive = isActive
        }
        override func isActive() -> Bool {
            return _underlyingIsActive
        }
    }
#endif
}
