@testable import Sentry
import XCTest

class SentrySessionTrackerTests: XCTestCase {

    private var options: Options!
    private var currentDateProvider: TestCurrentDateProvider!
    private var hub: TestHub!
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

            hub = TestHub(client: TestClient(options: options), andScope: nil)
            SentrySDK.setCurrentHub(hub)

            sut = SessionTracker(options: options, currentDateProvider: currentDateProvider)
        } catch {
            XCTFail("Failed to create options")
        }

        sut.start()
    }

    func testNotInBackground() {
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testNotLongEnoughInBackground() {
        willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testLongEnoughInBackground() {
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
        willResignActive()
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10))
        didBecomeActive()

        assertSessionNotEnded()
    }

    func testTerminateWithNotInBackground() {
        willTerminate()

        XCTAssertEqual(currentDateProvider.date(), hub.endSessionTimestamp)
    }

    func testTerminateWithInBackground() {
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
