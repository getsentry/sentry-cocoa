@testable import Sentry
import XCTest

class SentryUIKitSessionTrackerTests: XCTestCase {
    
    private let sessionTrackingIntervalMillis: UInt = 10_000
    private var fileManager: SentryFileManager!
    private var hub: SentryHub!
    private var client: TestClient!
    private var currentDateProvider: TestCurrentDateProvider!
    
    private var sut: SentryUIKitSessionTracker!
    
    override func setUp() {
        super.setUp()
        
        let options = Options()
        options.dsn = TestConstants.dsnAsString
        options.releaseName = "SentrySessionTrackerIntegrationTests"
        options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
        
        client = TestClient(options: options)
        
        fileManager = try! SentryFileManager(dsn: SentryDsn())
        fileManager.deleteCurrentSession()
        fileManager.deleteTimestampLastInForeground()
        
        hub = SentryHub(client: client, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
        sut = SentryUIKitSessionTracker(options: options, currentDateProvider: currentDateProvider)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
    }
    
    func testForegroundSendsInit() {
        sut.start()
        goToForeground()
        
        assertSessionInitSent()
        assertSessionStored()
    }
    
    func testForeground_Background_TrackingIntervalNotReached() {
        sut.start()
        
        goToForeground()
        advanceTime(by: 1)
        goToBackground()
        advanceTime(by: 8)
        goToForeground()
        
        assertSentSessions(count: 1)
    }
    
    func testForeground_Background_TrackingIntervalReached() {
        let startTime = currentDateProvider.date()
        sut.start()
        
        goToForeground()
        advanceTime(by: 1)
        goToBackground()
        
        goToForeground()
        advanceTime(by: 9)
        goToBackground()
        
        advanceTime(by: 20)
        goToForeground()
        assertEndSession(started: startTime, duration: 10)
    }
    
    func testForegroundWithError() {
        let startTime = currentDateProvider.date()
        sut.start()
        goToForeground()
        
        SentrySDK.capture(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"]))
        
        advanceTime(by: 10)
        goToBackground()
        goToForeground()
        
        assertEndSession(started: startTime, duration: 10, errors: 1)
    }
    
    func testLaunchFromBackground_AppNotRunning() {
        launchFromBackgroundNotRunning()
        
        assertSessionNotStored()
        assertLastInForegroundIsNil()
    }
    
    func testLaunchFromBackground_AppWasRunning_UserOpensApp() {
        let startTime = currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(by: 20)
        goToBackground()
        
        // Background task is launched
        advanceTime(by: 30)
        goToBackground()
        
        // user opens app
        advanceTime(by: 20)
        goToForeground()
        
        assertEndSession(started: startTime, duration: 20)
    }
    
    func testLaunchFromBackground_AppWasNotRunning_UserOpensApp() {
        sut.start()
        goToBackground()
        
        advanceTime(by: 10)
        let startTime = currentDateProvider.date()
        
        // user opens app
        goToForeground()
        advanceTime(by: 20)
        goToBackground()
        
        goToForeground()
        assertEndSession(started: startTime, duration: 20)
    }
    
    func testForeground_Background_Terminate() {
        let startTime = currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(by: 9)
        goToBackground()
        
        advanceTime(by: 1)
        terminateApp()
        
        assertEndSession(started: startTime, duration: 9)
        
        advanceTime(by: 10)
        
        // start app again
        // TODO: Unregister notifications from first SessionTracker to be able to test
        // if session init was sent.
        sut.start()
        goToForeground()
        assertLastInForegroundIsNil()
    }
    
    func testLaunchFromBackground_AppWasNotRunning_Terminate() {
        launchFromBackgroundNotRunning()
        
        terminateApp()
        assertNoSessionSent()
    }
    
    func testLaunchFromBackground_AppWasRunning_Terminate() {
        let startTime = currentDateProvider.date()
        sut.start()
        goToForeground()
        advanceTime(by: 2)
        goToBackground()
        
        terminateApp()
        
        assertEndSession(started: startTime, duration: 2)
    }
    
    private func launchFromBackgroundNotRunning() {
        sut.start()
        TestNotificationCenter.didEnterBackground()
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
    }
    
    private func advanceTime(by: TimeInterval) {
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(by))
    }
    
    private func resumeAppInBackground() {
        TestNotificationCenter.didEnterBackground()
    }
    
    private func assertSessionNotStored() {
        XCTAssertNil(fileManager.readCurrentSession())
    }
    
    private func assertSessionStored() {
        XCTAssertNotNil(fileManager.readCurrentSession())
    }
    
    private func assertNoSessionSent() {
        XCTAssertEqual(0, client.sessions.count)
    }
    
    private func assertEndSession(started: Date, duration: NSNumber, errors: UInt = 0) {
        
        // the end session is the second but last, because the sdk sends an session
        // init after sending the end of the session.
        
        let endSessionIndex = client.sessions.count - 2
        
        if let session = client?.sessions[endSessionIndex] {
            XCTAssertFalse(session.flagInit?.boolValue ?? false)
            XCTAssertNotNil(session.sessionId)
            XCTAssertEqual(started, session.started)
            XCTAssertEqual(SentrySessionStatus.exited, session.status)
            XCTAssertEqual(errors, session.errors)
            XCTAssertNotNil(session.distinctId)
            XCTAssertEqual(started.addingTimeInterval(TimeInterval(truncating: duration)), session.timestamp)
            XCTAssertEqual(duration, session.duration)
            XCTAssertNil(session.environment)
            XCTAssertNil(session.user)
        } else {
            XCTFail("No session was sent.")
        }
        
    }
    
    private func assertSessionInitSent() {
        if let session = client.sessions.first {
            XCTAssertTrue(session.flagInit?.boolValue ?? false)
            XCTAssertNotNil(session.sessionId)
            XCTAssertNotNil(session.started) // TODO: check for date
            XCTAssertEqual(SentrySessionStatus.ok, session.status)
            XCTAssertEqual(0, session.errors)
            XCTAssertNotNil(session.distinctId)
            XCTAssertNil(session.timestamp)
            XCTAssertNil(session.duration)
            XCTAssertNil(session.environment)
            XCTAssertNil(session.user)
        } else {
            XCTFail("No session init sent.")
        }
    }
    
    private func assertSentSessions(count: Int) {
        XCTAssertEqual(count, client.sessions.count)
    }
    
    private func assertLastInForegroundIsNil() {
        XCTAssertNil(fileManager.readTimestampLastInForeground())
    }
    
    private func assertLastInForegroundStored() {
        XCTAssertEqual(currentDateProvider.date(), fileManager.readTimestampLastInForeground())
    }
}
