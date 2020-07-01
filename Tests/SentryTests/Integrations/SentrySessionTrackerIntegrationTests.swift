@testable import Sentry
import XCTest

class SentrySessionTrackerIntegrationTests: XCTestCase {
    
    private class Fixture {
        
        var currentDateProvider = TestCurrentDateProvider()
        var hub: SentryHub!
        var fileManager: SentryFileManager!
        var client: TestClient!
        private let sessionTrackingIntervalMillis : UInt = 10_000
        
        init() {
            fileManager = try! SentryFileManager(dsn: SentryDsn())
        }
        
        func getSut() -> SessionTracker {
            let options = Options()
            options.dsn = TestConstants.dsnAsString
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
            
            client = TestClient(options: options)
            
            hub = SentryHub(client: client, andScope: nil)
            SentrySDK.setCurrentHub(hub)
            
            CurrentDate.setCurrentDateProvider(currentDateProvider)
            
            return SessionTracker(options: options, currentDateProvider: currentDateProvider)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteTimestampLastInForeground()
    }
    
    func testLaunchAppInForeground() {
        fixture.getSut().start()
        goToForeground()
        
        assertSessionInitSent()
        assertSessionStored()
    }
    
    func testInForeground_Background() {
        let startTime = fixture.currentDateProvider.date()
        fixture.getSut().start()
        
        goToForeground()
        advanceTime(by: 1)
        
        goToBackground()
        assertEndSession(started: startTime, duration: 1)
    }
    
    func testSessionEnded_NotLongEnoughInBackground_DoesNotStartSession() {
        let startTime = fixture.currentDateProvider.date()
        fixture.getSut().start()
        
        goToForeground()
        advanceTime(by: 9)
        
        goToBackground()
        assertEndSession(started: startTime, duration: 9)
        
        goToForeground()
        assertSentSessions(count: 2)
    }
    
    func testSessionEnded_LongEnoughInBackground_StartsSession() {
           let startTime = fixture.currentDateProvider.date()
           fixture.getSut().start()
           
           goToForeground()
           advanceTime(by: 10)
           
           goToBackground()
           assertEndSession(started: startTime, duration: 10)
           
           goToForeground()
           assertSentSessions(count: 3)
       }
    
    func testGotForeground_GoToBackground_DurationTooShort_GoToForeground() {
        let startTime = fixture.currentDateProvider.date()
        fixture.getSut().start()
        
        goToForeground()
        advanceTime(by: 9)
        
        goToBackground()
        assertSentSessions(count: 1)
        
        goToForeground()
        assertSentSessions(count: 1)
        
        advanceTime(by: 1)
        goToBackground()
        assertEndSession(started: startTime, duration: 10)
    }
    

  
    
    func testLaunchFromBackground_AppNotRunning() {
        launchFromBackgroundNotRunning()
        
        assertSessionNotStored()
        assertLastInForegroundIsNil()
    }
    
    func testLaunchFromBackground_AppWasInForegroundAndIsResumed() {
        fixture.getSut().start()
        assertSessionStored()
        assertSessionInitSent()
        
        goToForeground()
        assertLastInForegroundIsNil()
        assertSentSessions(count: 1)
        
        advanceTime(by: 1)
        goToBackground()
        assertLastInForegroundStored()
        
        resumeAppInBackground()
        assertLastInForegroundStored()
        assertSessionStored()
        
        terminateApp()
        assertSentSessions(count: 1)
        assertLastInForegroundStored()
    }
    
    func testLaunchFromBackground_AppWasInBackgroundAndIsResumed() {
        
    }
    
    func testFromLaunchBackground_FromForeground() {
        fixture.getSut().start()
        
        postNotificationsForBackgroundExecutionFromForeground()
        
        assertSessionStored()
        
        assertLastInForegroundStored()
    }
    
    func testTerminateAfterForeground() {
        
    }
    
    func testTerminateInBackgroundAfterForeground() {
        
    }
    
    func testTerminateAfterOnlyBackground() {
        launchFromBackgroundNotRunning()
        
        terminateApp()
        assertNoSessionSent()
        assertLastInForegroundIsNil()
    }
    
    private func postNotificationsForBackgroundExecutionFromForeground() {
        // Docs about background execution sequence https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/about_the_background_execution_sequence
        TestNotificationCenter.didBecomeActive()
        TestNotificationCenter.willResignActive()
        TestNotificationCenter.didEnterBackground()
    }
    
    private func launchFromBackgroundNotRunning() {
        fixture.getSut().start()
        TestNotificationCenter.didEnterBackground()
    }
    
    private func launchFromBackgroundAppWasInBackgroundAndStillInMemory() {
        
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
        XCTAssertEqual(0,  fixture.client.sessions.count)
    }
    
    private func assertEndSession(started: Date, duration: NSNumber) {
        let session = fixture.client.sessions[1]
        XCTAssertFalse(session.flagInit?.boolValue ?? false)
        XCTAssertNotNil(session.sessionId)
        XCTAssertEqual(started, session.started)
        XCTAssertEqual(SentrySessionStatus.exited, session.status)
        XCTAssertEqual(0, session.errors)
        XCTAssertNotNil(session.distinctId)
        XCTAssertEqual(fixture.currentDateProvider.date(), session.timestamp)
        XCTAssertEqual(duration, session.duration)
        XCTAssertNil(session.environment)
        XCTAssertNil(session.user)
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
