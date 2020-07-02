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
    private var sut: SessionTracker!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
        sut = fixture.getSut()
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
    }

    func testStartClosesPreviousCachedSession() {
        sut.start()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testStartClosesPreviousCachedSessionWithoutSavedTimestamp() {
        fixture.fileManager.timestampLastInForeground = nil
        sut.start()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testStoresTimestampWhenInBackground() {
        fixture.fileManager.timestampLastInForeground = nil
        sut.start()

        willResignActive()

        XCTAssertEqual(1, fixture.fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fixture.fileManager.deleteTimestampLastInForegroundInvocations)
        
        XCTAssertEqual(1, fixture.fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.fileManager.timestampLastInForeground)
    }

    func testNotInBackground() {
        sut.start()

        didBecomeActive()

        assertSessionNotEnded()
    }

    func testNotLongEnoughInBackground() {
        sut.start()

        willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testLongEnoughInBackground() {
        sut.start()

        let expectedEndSessionTimestamp = fixture.currentDateProvider.date()

        willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10.01))
        didBecomeActive()

        // Session ended
        XCTAssertEqual(expectedEndSessionTimestamp, fixture.hub.endSessionTimestamp)
        XCTAssertEqual(2, fixture.hub.startSessionInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }

    func testForegroundResetsBackground() {
        sut.start()

        willResignActive()
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testTerminateWithNotInBackground() {
        sut.start()

        willTerminate()

        XCTAssertEqual(fixture.currentDateProvider.date(), fixture.hub.endSessionTimestamp)
    }

    func testTerminateWithInBackground() {
        sut.start()

        let expectedEndSessionTimestamp = fixture.currentDateProvider.date().addingTimeInterval(1)
        fixture.currentDateProvider.setDate(date: expectedEndSessionTimestamp)

        willResignActive()
        willTerminate()

        XCTAssertEqual(expectedEndSessionTimestamp, fixture.hub.endSessionTimestamp)
    }

    private func willTerminate() {
        NotificationCenter.default.post(Notification(name: UIApplication.willTerminateNotification))
    }

    private func didBecomeActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.didBecomeActiveNotification))
    }

    private func willResignActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.willResignActiveNotification))
    }

    private func assertSessionNotEnded() {
        XCTAssertNil(fixture.hub.endSessionTimestamp)
        XCTAssertEqual(1, fixture.hub.startSessionInvocations)
        XCTAssertEqual(1, fixture.hub.closeCachedSessionInvocations)
    }
}
