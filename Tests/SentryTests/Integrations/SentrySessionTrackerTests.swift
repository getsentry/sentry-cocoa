@testable import Sentry
import XCTest

class SentrySessionTrackerTests: XCTestCase {

    private class Fixture {
        
        private let sessionTrackingIntervalMillis: UInt = 10_000
        var currentDateProvider = TestCurrentDateProvider()
        var hub: TestHub!
        var fileManager: TestFileManager!
        
        func getSut() -> SessionTracker {
            let options = Options()
            options.dsn = TestConstants.dsnAsString
            options.releaseName = "SentrySessionTrackerTests"
            options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
            
            fileManager = try! TestFileManager(dsn: SentryDsn())
            let client = TestClient(options: options)
            client?.sentryFileManager = fileManager
            
            hub = TestHub(client: client, andScope: nil)
            SentrySDK.setCurrentHub(hub)
            
            return SessionTracker(options: options, currentDateProvider: currentDateProvider)
        }
    }
    
    private var fixture: Fixture!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
    }

    func testStartClosesPreviousCachedSession() {
        fixture.getSut().start()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testStartClosesPreviousCachedSessionWithoutSavedTimestamp() {
        let sut = fixture.getSut()
        fixture.fileManager.timestampLastInForeground = nil
        sut.start()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testStoresTimestampWhenInBackground() {
        let sut = fixture.getSut()
        fixture.fileManager.timestampLastInForeground = nil
        sut.start()

        TestNotificationCenter.willResignActive()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        
        // TODO: Multiple observers are added at the notification center. We never remove them, that's why we have multiple invocations here. Fix this.
        XCTAssertEqual(8, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.fileManager.timestampLastInForeground)
    }

    func testNotInBackground() {
        fixture.getSut().start()

        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testNotLongEnoughInBackground() {
        fixture.getSut().start()

        TestNotificationCenter.willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testLongEnoughInBackground() {
        fixture.getSut().start()

        let expectedEndSessionTimestamp = fixture.currentDateProvider.date()

        TestNotificationCenter.willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10.01))
        TestNotificationCenter.didBecomeActive()

        // Session ended
        XCTAssertEqual(expectedEndSessionTimestamp, fixture.hub.endSessionTimestamp)
        XCTAssertEqual(2, fixture.hub.startSessionInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testForegroundResetsBackground() {
        fixture.getSut().start()

        TestNotificationCenter.willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testTerminateWithNotInBackground() {
        fixture.getSut().start()

        TestNotificationCenter.willTerminate()

        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.hub.endSessionTimestamp)
    }

    func testTerminateWithInBackground() {
        fixture.getSut().start()

        let expectedEndSessionTimestamp = fixture.currentDateProvider.date().addingTimeInterval(1)
        fixture.currentDateProvider.setDate(date: expectedEndSessionTimestamp)

        TestNotificationCenter.willResignActive()
        TestNotificationCenter.willTerminate()

        XCTAssertEqual(expectedEndSessionTimestamp, fixture.hub.endSessionTimestamp)
    }

    private func assertSessionNotEnded() {
        XCTAssertNil(fixture.hub.endSessionTimestamp)
        XCTAssertEqual(1, fixture.hub.startSessionInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }
}
