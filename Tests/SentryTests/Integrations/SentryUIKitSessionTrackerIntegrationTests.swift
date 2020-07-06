@testable import Sentry
import XCTest

class SentryUIKitSessionTrackerIntegrationTests: XCTestCase {
    
    private class Fixture {
        
        var currentDateProvider = TestCurrentDateProvider()
        var hub: SentryHub!
        var fileManager: SentryFileManager!
        var client: TestClient!
        private let sessionTrackingIntervalMillis: UInt = 10_000
        
        init() {
            fileManager = try! SentryFileManager(dsn: SentryDsn())
        }
        
        func getSut() -> SentryUIKitSessionTracker {
            let options = Options()
            options.dsn = TestConstants.dsnAsString
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
            
            client = TestClient(options: options)
            
            hub = SentryHub(client: client, andScope: nil)
            SentrySDK.setCurrentHub(hub)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
            
            return SentryUIKitSessionTracker(options: options, currentDateProvider: currentDateProvider)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryUIKitSessionTracker!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteTimestampLastInForeground()
        
        sut = fixture.getSut()
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
        let startTime = fixture.currentDateProvider.date()
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
        let startTime = fixture.currentDateProvider.date()
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
        let startTime = fixture.currentDateProvider.date()
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
        let startTime = fixture.currentDateProvider.date()
        
        // user opens app
        goToForeground()
        advanceTime(by: 20)
        goToBackground()
        
        goToForeground()
        assertEndSession(started: startTime, duration: 20)
    }
    
    func testForeground_Background_Terminate() {
        let startTime = fixture.currentDateProvider.date()
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
        fixture.getSut().start()
        goToForeground()
        assertLastInForegroundIsNil()
    }
    
    func testLaunchFromBackground_AppWasNotRunning_Terminate() {
        launchFromBackgroundNotRunning()
        
        terminateApp()
        assertNoSessionSent()
    }
    
    func testLaunchFromBackground_AppWasRunning_Terminate() {
        let startTime = fixture.currentDateProvider.date()
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
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(by))
    }
    
    private func resumeAppInBackground() {
        TestNotificationCenter.didEnterBackground()
    }
    
    private func assertSessionNotStored() {
        XCTAssertNil(fixture.fileManager.readCurrentSession())
    }
    
    private func assertSessionStored() {
        XCTAssertNotNil(fixture.fileManager.readCurrentSession())
    }
    
    private func assertNoSessionSent() {
        XCTAssertEqual(0, fixture.client.sessions.count)
    }
    
    private func assertEndSession(started: Date, duration: NSNumber, errors: UInt = 0) {
        
        // the end session is the second but last, because the sdk sends an session
        // init after sending the end of the session.
        
        let endSessionIndex = fixture.client.sessions.count - 2
        
        if let session = fixture.client?.sessions[endSessionIndex] {
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
        if let session = fixture.client.sessions.first {
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
        XCTAssertEqual(count, fixture.client.sessions.count)
    }
    
    private func assertLastInForegroundIsNil() {
        XCTAssertNil(fixture.fileManager.readTimestampLastInForeground())
    }
    
    private func assertLastInForegroundStored() {
        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.fileManager.readTimestampLastInForeground())
    }
}
