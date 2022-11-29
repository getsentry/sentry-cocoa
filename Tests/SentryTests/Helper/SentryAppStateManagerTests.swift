import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStateManagerTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryOutOfMemoryTrackerTests")
    private static let dsn = TestConstants.dsn(username: "SentryOutOfMemoryTrackerTests")

    private class Fixture {

        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()

        init() {
            options = Options()
            options.dsn = SentryAppStateManagerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName

            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate, dispatchQueueWrapper: dispatchQueue)
        }

        func getSut() -> SentryAppStateManager {
            return SentryAppStateManager(
                options: options,
                crashWrapper: TestSentryCrashWrapper.sharedInstance(),
                fileManager: fileManager,
                currentDateProvider: currentDate,
                sysctl: TestSysctl(),
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
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

    func testForcedStop() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        sut.start()
        sut.start()
        sut.start()

        sut.stop()
        XCTAssertEqual(sut.startCount, 3)

        sut.stop(true)
        XCTAssertEqual(sut.startCount, 0)
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
