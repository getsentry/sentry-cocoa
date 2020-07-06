@testable import Sentry
import XCTest

class SentryUIKitSessionTrackerTests: XCTestCase {

    private let sessionTrackingIntervalMillis: UInt = 10_000
    private var currentDateProvider: TestCurrentDateProvider!
    private var hub: TestHub!
    private var fileManager: TestFileManager!

    private var sut: SessionTracker!

    override func setUp() {
        super.setUp()
        
        let options = Options()
        options.dsn = TestConstants.dsnAsString
        options.releaseName = "SentrySessionTrackerTests"
        options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis

        fileManager = try! TestFileManager(dsn: SentryDsn())
        let client = TestClient(options: options)
        client?.sentryFileManager = fileManager

        hub = TestHub(client: client, andScope: nil)
        SentrySDK.setCurrentHub(hub)

        currentDateProvider = TestCurrentDateProvider()

        sut = SentryUIKitSessionTracker(options: options, currentDateProvider: currentDateProvider)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
    }

    func testStartClosesPreviousCachedSession() {
        fileManager.timestampLastInForeground = currentDateProvider.date()
        sut.start()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testStartClosesPreviousCachedSessionWithoutSavedTimestamp() {
        sut.start()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testStoresTimestampWhenInBackground() {
        sut.start()

        TestNotificationCenter.willResignActive()

        TestNotificationCenter.willResignActive()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.deleteTimestampLastInForegroundInvocations)
        
        XCTAssertEqual(1, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(currentDateProvider.date(), fileManager.timestampLastInForeground)
    }

    func testNotInBackground() {
        sut.start()

        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testNotLongEnoughInBackground() {
        sut.start()

        TestNotificationCenter.willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testLongEnoughInBackground() {
        sut.start()
        let expectedEndSessionTimestamp = currentDateProvider.date()

        TestNotificationCenter.willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.01))
        TestNotificationCenter.didBecomeActive()

        // Session ended
        XCTAssertEqual(expectedEndSessionTimestamp, hub.endSessionTimestamp)
        XCTAssertEqual(2, hub.startSessionInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testForegroundResetsBackground() {
        sut.start()

        TestNotificationCenter.willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        TestNotificationCenter.didBecomeActive()

        assertSessionNotEnded()
    }

    func testTerminateWithNotInBackground() {
        sut.start()

        TestNotificationCenter.willTerminate()

        XCTAssertEqual(currentDateProvider.date(), hub.endSessionTimestamp)
    }

    func testTerminateWithInBackground() {
        sut.start()

        let expectedEndSessionTimestamp = currentDateProvider.date().addingTimeInterval(1)
        currentDateProvider.setDate(date: expectedEndSessionTimestamp)

        TestNotificationCenter.willResignActive()
        TestNotificationCenter.willTerminate()

        XCTAssertEqual(expectedEndSessionTimestamp, hub.endSessionTimestamp)
    }

    private func assertSessionNotEnded() {
        XCTAssertNil(hub.endSessionTimestamp)
        XCTAssertEqual(1, hub.startSessionInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }
}
