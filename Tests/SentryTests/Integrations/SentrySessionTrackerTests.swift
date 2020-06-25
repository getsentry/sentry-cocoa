@testable import Sentry
import XCTest

class SentrySessionTrackerTests: XCTestCase {

    private var options: Options!
    private var currentDateProvider: TestCurrentDateProvider!
    private var hub: TestHub!
    private var client: TestClient!
    private var fileManager: TestFileManager!
    private let sessionTrackingIntervalMillis: UInt = 10_000
    private var sut: SessionTracker!

    override func setUp() {
        super.setUp()

        currentDateProvider = TestCurrentDateProvider()

        do {
            let optionsDict = ["dsn": TestConstants.dsnAsString,
                               "release": "SentrySessionTrackerTests",
                               "sessionTrackingIntervalMillis": sessionTrackingIntervalMillis] as [String: Any]
            let options = try Options(dict: optionsDict)

            client = TestClient(options: options)
            fileManager = try! TestFileManager(dsn: SentryDsn())
            client.sentryFileManager = fileManager
            hub = TestHub(client: client, andScope: nil)
            SentrySDK.setCurrentHub(hub)

            sut = SessionTracker(options: options, currentDateProvider: currentDateProvider)
        } catch {
            XCTFail("Failed to setup test")
        }
    }

    func testStartClosesPreviousCachedSession() {
        sut.start()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testStartClosesPreviousCachedSessionWithoutSavedTimestamp() {
        fileManager.timestampLastInForeground = nil

        sut.start()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.deleteTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testStoresTimestampWhenInBackground() {
        fileManager.timestampLastInForeground = nil

        sut.start()

        willResignActive()

        XCTAssertEqual(1, fileManager.readTimestampLastInForegroundInvocations)
        XCTAssertEqual(0, fileManager.deleteTimestampLastInForegroundInvocations)
        
        // TODO: Multiple observers are added at the notification center. We never remove them, that's why we have multiple invocations here. Fix this.
        XCTAssertEqual(8, fileManager.storeTimestampLastInForegroundInvocations)
        XCTAssertEqual(currentDateProvider.date(), fileManager.timestampLastInForeground)
    }

    func testNotInBackground() {
        sut.start()

        didBecomeActive()

        assertSessionNotEnded()
    }

    func testNotLongEnoughInBackground() {
        sut.start()

        willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testLongEnoughInBackground() {
        sut.start()

        let expectedEndSessionTimestamp = currentDateProvider.date()

        willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.01))
        didBecomeActive()

        // Session ended
        XCTAssertEqual(expectedEndSessionTimestamp, hub.endSessionTimestamp)
        XCTAssertEqual(2, hub.startSessionInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }

    func testForegroundResetsBackground() {
        sut.start()

        willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testTerminateWithNotInBackground() {
        sut.start()

        willTerminate()

        XCTAssertEqual(currentDateProvider.date(), hub.endSessionTimestamp)
    }

    func testTerminateWithInBackground() {
        sut.start()

        let expectedEndSessionTimestamp = currentDateProvider.date().addingTimeInterval(1)
        currentDateProvider.setDate(date: expectedEndSessionTimestamp)

        willResignActive()
        willTerminate()

        XCTAssertEqual(expectedEndSessionTimestamp, hub.endSessionTimestamp)
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
        XCTAssertNil(hub.endSessionTimestamp)
        XCTAssertEqual(1, hub.startSessionInvocations)
        XCTAssertEqual(1, hub.closeCachedSessionInvocations)
    }
}
