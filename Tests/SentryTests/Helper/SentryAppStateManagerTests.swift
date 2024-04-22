import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStateManagerTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")

    private class Fixture {

        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()

        init() {
            options = Options()
            options.dsn = SentryAppStateManagerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName

            fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueue)
        }

        func getSut() -> SentryAppStateManager {
            SentryDependencyContainer.sharedInstance().sysctlWrapper = TestSysctl()
            return SentryAppStateManager(
                options: options,
                crashWrapper: TestSentryCrashWrapper.sharedInstance(),
                fileManager: fileManager,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                notificationCenterWrapper: notificationCenterWrapper
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryAppStateManager!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
        sut = fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAppState()
        clearTestState()
    }

    func testStartStoresAppState() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())
    }

    func testStartOnlyRunsLogicWhenStartCountBecomesOne() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())

        fixture.fileManager.deleteAppState()

        sut.start()
        XCTAssertNil(fixture.fileManager.readAppState())
    }

    func testStopDoesNotDeleteAppState() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())

        sut.stop()
        XCTAssertNotNil(fixture.fileManager.readAppState())
    }

    func testStopUpdatesAppState() {
        sut.start()

        let stateBeforeStop = fixture.fileManager.readAppState()
        XCTAssertTrue(stateBeforeStop!.isSDKRunning)

        sut.stop(withForce: true)

        let stateAfterStop = fixture.fileManager.readAppState()
        XCTAssertFalse(stateAfterStop!.isSDKRunning)
    }

    func testForcedStop() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        sut.start()
        sut.start()

        sut.stop()
        XCTAssertEqual(sut.startCount, 2)

        sut.stop(withForce: true)
        XCTAssertEqual(sut.startCount, 0)

        XCTAssertEqual(fixture.notificationCenterWrapper.removeObserverWithNameInvocations.count, 6)
    }

    func testUpdateAppState() {
        sut.storeCurrentAppState()

        XCTAssertEqual(fixture.fileManager.readAppState()!.wasTerminated, false)

        sut.updateAppState { state in
            state.wasTerminated = true
        }

        XCTAssertEqual(fixture.fileManager.readAppState()!.wasTerminated, true)
    }
}
#endif
