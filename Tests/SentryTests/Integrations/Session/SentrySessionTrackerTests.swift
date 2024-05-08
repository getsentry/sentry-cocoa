@testable import Sentry
import SentryTestUtils
import XCTest

class SentrySessionTrackerTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySessionTrackerTests")
    
    private class Fixture {
        
        let options: Options
        let currentDateProvider = TestCurrentDateProvider()
        let client: TestClient!
        let sentryCrash: TestSentryCrashWrapper

        let notificationCenter = TestNSNotificationCenterWrapper()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        lazy var fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueue)
        
        init() {
            options = Options()
            options.dsn = SentrySessionTrackerTests.dsnAsString
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = 10_000
            options.environment = "debug"
            
            client = TestClient(options: options)
            
            sentryCrash = TestSentryCrashWrapper.sharedInstance()
        }
        
        func getSut() -> SessionTracker {
            return SessionTracker(options: options, notificationCenter: notificationCenter)
        }
        
        func setNewHubToSDK() {
            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: self.sentryCrash, andDispatchQueue: SentryDispatchQueueWrapper())
            SentrySDK.setCurrentHub(hub)
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
        sut.stop()
        clearTestState()
        
        super.tearDown()
    }
    
    func testOnlyForeground() {
        sut.start()
        goToForeground()
        
        assertInitSessionSent()
        assertSessionStored()
    }
    
    func testOnlyHybridSdkDidBecomeActive() {
        sut.start()
        hybridSdkDidBecomeActive()
        
        assertInitSessionSent()
        assertSessionStored()
    }
    
    func testForeground_And_HybridSdkDidBecomeActive() {
        sut.start()
        goToForeground()
        hybridSdkDidBecomeActive()
        
        assertInitSessionSent()
        assertSessionStored()
    }
    
    func testHybridSdkDidBecomeActive_and_Foreground() {
        sut.start()
        hybridSdkDidBecomeActive()
        
        goToForeground()
        
        assertInitSessionSent()
        assertSessionStored()
    }
    
    func testForeground_Background_TrackingIntervalNotReached() {
        sut.start()
        
        let sessionStarted = fixture.currentDateProvider.date()
        goToForeground()
        advanceTime(bySeconds: 11)
        
        goToBackground(forSeconds: 9)
        
        assertSessionInitSent(sessionStarted: sessionStarted)
    }
    
    func testForeground_Background_TrackingIntervalReached() {
        sut.start()
        
        let sessionStarted = fixture.currentDateProvider.date()
        goToForeground()
        advanceTime(bySeconds: 1)
        
        goToBackground(forSeconds: 9)
        
        // Session not sent yet
        assertSessionsSent(count: 1)
        advanceTime(bySeconds: 1)
        
        goToBackground(forSeconds: 10)
        
        assertEndSessionSent(started: sessionStarted, duration: 11)
    }
    
    func testCrashInForeground_LaunchInForeground() {
        crashInForeground()
        
        assertAppLaunchSendsCrashedSession()
        
        goToForeground()
        assertSessionsSent(count: 3)
        assertInitSessionSent()
    }
    
    func testCrashInForeground_LaunchInBackground() {
        crashInForeground()
        
        assertAppLaunchSendsCrashedSession()
        
        goToBackground()
        
        // only two sessions. First is the init, second is the crashed one,
        // but no extra init is sent.
        assertSessionsSent(count: 2)
        assertNoInitSessionSent()
    }
    
    func testCrashInBackground_LaunchInForeground() {
        crashInBackground()
        assertNoSessionSent()
        
        sut = fixture.getSut()
        sut.start()
        assertNoSessionSent()
        
        goToForeground()
        assertInitSessionSent()
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
        let sessionStartTime = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        goToBackground(forSeconds: 2)
        advanceTime(bySeconds: 2)
        // Terminate and goToBackground not called intenionally, because we don't want to end the session
        sut.stop()
        
        advanceTime(bySeconds: 1)
        sut = fixture.getSut()
        fixture.setNewHubToSDK()
        
        sut.start()
        assertSessionSent(started: sessionStartTime, duration: 0, status: SentrySessionStatus.abnormal)
    }
    
    func testTerminateWithoutCallingTerminateNotification() {
        let sessionStartTime = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 5)
        goToBackground()
        // Terminate not called intenionally, because we don't want to end the session properly
        sut.stop()
        
        advanceTime(bySeconds: 1)
        sut = fixture.getSut()
        fixture.setNewHubToSDK()
        
        sut.start()
        assertSessionSent(started: sessionStartTime, duration: 5, status: SentrySessionStatus.exited)
    }
    
    func testForegroundWithError() {
        let startTime = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()

        advanceTime(bySeconds: 1)
        captureError()
        advanceTime(bySeconds: 1)

        goToBackground()
        captureError()
        advanceTime(bySeconds: 10)
        goToForeground()

        assertEndSessionSent(started: startTime, duration: 2, errors: 2)
    }
    
    func testAppNotRunning_LaunchBackgroundTask() {
        launchBackgroundTaskAppNotRunning()
        
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
    
    func testAppRunning_LaunchBackgroundTaskImmediately_UserResumesApp() {
        let sessionStarted = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 1)
        goToBackground()
        
        // Background task is launched
        advanceTime(bySeconds: 2)
        
        // user opens app
        goToForeground()
        assertSessionInitSent(sessionStarted: sessionStarted)
        assertSessionsSent(count: 1)
    }
    
    func testAppNotRunning_LaunchBackgroundTask_UserOpensApp() {
        launchBackgroundTaskAppNotRunning()
        advanceTime(bySeconds: 10)
        
        // user opens app
        let sessionStarted = fixture.currentDateProvider.date()
        goToForeground()
        assertInitSessionSent()
        
        advanceTime(bySeconds: 1)
        
        goToBackground(forSeconds: 10)
        
        assertEndSessionSent(started: sessionStarted, duration: 1)
    }
    
    func testForeground_Background_Terminate_LaunchAgain() {
        let sessionStartTime = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 1)
        goToBackground()
        
        advanceTime(bySeconds: 10)
        terminateApp()
        assertEndSessionSent(started: sessionStartTime, duration: 1)
        sut.stop()
        
        advanceTime(bySeconds: 1)
        
        // Launch the app again
        fixture.setNewHubToSDK()
        sut = fixture.getSut()
        sut.start()
        
        goToForeground()
        assertInitSessionSent()
    }
    
    func testAppNotRunning_LaunchFromBackground_Terminate() {
        launchBackgroundTaskAppNotRunning()
        
        terminateApp()
        
        assertNoSessionSent()
    }
    
    func testAppRunningInForeground_LaunchFromBackground_Terminate() {
        let startTime = fixture.currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(bySeconds: 2)
        goToBackground()
        
        terminateApp()
        
        assertEndSessionSent(started: startTime, duration: 2)
    }
    
    func testForeground_Background_Foreground_NoSessionToEnd() {
        sut.start()
        goToForeground()
        goToBackground()
        advanceTime(bySeconds: 10)
        
        fixture.setNewHubToSDK()
        goToForeground()
        
        assertInitSessionSent()
        assertSessionsSent(count: 2)
    }
    
    func testStart_AddsObservers() {
        sut.start()
        
        let invocations = fixture.notificationCenter.addObserverInvocations
        let notificationNames = invocations.invocations.map { $0.name }
        
        assertNotificationNames(notificationNames)
    }
    
    func testStop_RemovesObservers() {
        sut.stop()
        
        let invocations = fixture.notificationCenter.removeObserverWithNameInvocations
        let notificationNames = invocations.invocations.map { $0.name }
        
        assertNotificationNames(notificationNames)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
    
    private func goToForeground() {
        Dynamic(sut).didBecomeActive()
    }
    
    private func goToBackground() {
        willResignActive()
    }
    
    private func willResignActive() {
        Dynamic(sut).willResignActive()
    }
    
    private func hybridSdkDidBecomeActive() {
        Dynamic(sut).didBecomeActive()
    }
    
    private func goToBackground(forSeconds: TimeInterval) {
        goToBackground()
        advanceTime(bySeconds: forSeconds)
        goToForeground()
    }
    
    private  func willTerminate() {
        Dynamic(sut).willTerminate()
    }
    
    private func terminateApp() {
        willTerminate()
        sut.stop()
    }
    
    private func launchBackgroundTaskAppNotRunning() {
        sut.stop()
        fixture.setNewHubToSDK()
        sut = fixture.getSut()
        
        sut.start()
    }
    
    private func captureError() {
        SentrySDK.capture(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"]))
    }
    
    private func crashInForeground() {
        sut.start()
        goToForeground()
        // Terminate and background not called intenionally, because the app crashed
        sut.stop()
        fixture.sentryCrash.internalCrashedLastLaunch = true
    }
    
    private func crashInBackground() {
        sut.start()
        goToBackground()
        // Terminate not called intenionally, because the app crashed
        sut.stop()
        fixture.sentryCrash.internalCrashedLastLaunch = true
    }
    
    private func assertSessionNotStored() {
        XCTAssertNil(fixture.fileManager.readCurrentSession())
    }
    
    private func assertSessionStored() {
        XCTAssertNotNil(fixture.fileManager.readCurrentSession())
    }
    
    private func assertNoSessionSent() {
        XCTAssertEqual(0, fixture.client.captureSessionInvocations.count)
    }
    
    private func assertEndSessionSent(started: Date, duration: NSNumber, errors: UInt = 0) {
        
        // the end session is the second but last, because the sdk sends an session
        // init after sending the end of the session.
        let endSessionIndex = fixture.client.captureSessionInvocations.count - 2
        
        if fixture.client.captureSessionInvocations.invocations.indices.contains(endSessionIndex) {
            let session = fixture.client.captureSessionInvocations.invocations[endSessionIndex]
            XCTAssertFalse(session.flagInit?.boolValue ?? false)
            XCTAssertEqual(started, session.started)
            XCTAssertEqual(SentrySessionStatus.exited.description, session.status.description)
            XCTAssertEqual(errors, session.errors)
            XCTAssertEqual(started.addingTimeInterval(TimeInterval(truncating: duration)), session.timestamp)
            XCTAssertEqual(duration, session.duration)
            assertSessionFields(session: session)
        } else {
            XCTFail("Can't find EndSession.")
        }
    }
    
    private func assertSessionSent(started: Date, duration: NSNumber, status: SentrySessionStatus) {

        let endSessionIndex = fixture.client.captureSessionInvocations.count - 1

        if fixture.client.captureSessionInvocations.invocations.indices.contains(endSessionIndex) {
            let session = fixture.client.captureSessionInvocations.invocations[endSessionIndex]
            assertSession(session: session, started: started, status: status, duration: duration)
        } else {
            XCTFail("Can't find session.")
        }
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

    private func assertInitSessionSent() {
        assertSessionInitSent(sessionStarted: fixture.currentDateProvider.date())
    }
    
    private func assertSessionInitSent(sessionStarted: Date) {
        if let session = fixture.client.captureSessionInvocations.last {
            XCTAssertTrue(session.flagInit?.boolValue ?? false)
            XCTAssertEqual(sessionStarted, session.started)
            XCTAssertEqual(SentrySessionStatus.ok.description, session.status.description)
            XCTAssertEqual(0, session.errors)
            XCTAssertNil(session.timestamp)
            XCTAssertNil(session.duration)
            assertSessionFields(session: session)
        } else {
            XCTFail("No session init sent.")
        }
    }
    
    private func assertSessionFields(session: SentrySession) {
        XCTAssertNotNil(session.sessionId)
        XCTAssertNotNil(session.distinctId)
        XCTAssertEqual(fixture.options.environment, session.environment)
        XCTAssertNil(session.user)
    }
    
    private func assertNoInitSessionSent() {
        let eventWithSessions = fixture.client.captureCrashEventWithSessionInvocations.invocations.map({ triple in triple.session })
        let errorWithSessions = fixture.client.captureErrorWithSessionInvocations.invocations.map({ triple in triple.session })
        let exceptionWithSessions = fixture.client.captureExceptionWithSessionInvocations.invocations.map({ triple in triple.session })
        
        var sessions = fixture.client.captureSessionInvocations.invocations + eventWithSessions + errorWithSessions + exceptionWithSessions
        
        sessions.sort { first, second in return first!.started < second!.started }
        
        if let session = sessions.last {
            XCTAssertFalse(session?.flagInit?.boolValue ?? false)
        }
    }
    
    private func assertSessionsSent(count: Int) {
        let eventWithSessions = fixture.client.captureCrashEventWithSessionInvocations.count
        let errorWithSessions = fixture.client.captureErrorWithSessionInvocations.count
        let exceptionWithSessions = fixture.client.captureExceptionWithSessionInvocations.count
        let sessions = fixture.client.captureSessionInvocations.count
        
        let sessionsSent = eventWithSessions + errorWithSessions + exceptionWithSessions + sessions
        
        XCTAssertEqual(count, sessionsSent)
    }
    
    private func assertLastInForegroundIsNil() {
        XCTAssertNil(fixture.fileManager.readTimestampLastInForeground())
    }
    
    private func assertLastInForegroundStored() {
        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.fileManager.readTimestampLastInForeground())
    }
    
    private func assertAppLaunchSendsCrashedSession() {
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
        
        sut.start()
        SentrySDK.captureCrash(Event())
        
        if let session = fixture.client.captureCrashEventWithSessionInvocations.last?.session {
            assertSession(session: session, started: sessionStartTime, status: SentrySessionStatus.crashed, duration: 5)
        } else {
            XCTFail("No session sent with event.")
        }
    }
    
    private func assertNotificationNames(_ notificationNames: [NSNotification.Name]) {
        XCTAssertEqual(4, notificationNames.count)
        
        XCTAssertEqual([
            SentryNSNotificationCenterWrapper.didBecomeActiveNotificationName,
            NSNotification.Name(rawValue: SentryHybridSdkDidBecomeActiveNotificationName),
            SentryNSNotificationCenterWrapper.willResignActiveNotificationName,
            SentryNSNotificationCenterWrapper.willTerminateNotificationName
        ], notificationNames)
    }
}
