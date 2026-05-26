@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryKSCrashIntegrationSessionHandlerTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryKSCrashIntegrationSessionHandlerTests")

    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let crashReporter: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let options: Options

        init() throws {
            crashReporter = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
            crashReporter.internalActiveDurationSinceLastCrash = 5.0
            crashReporter.internalCrashedLastLaunch = true

            options = Options()
            options.dsn = SentryKSCrashIntegrationSessionHandlerTests.dsnAsString

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
        }

        var session: SentrySession {
            let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
            session.incrementErrors()
            return session
        }

        func makeSUT(crashReporter: SentryCrashReporter? = nil) -> SentryKSCrashIntegrationSessionHandler {
            let reporter = crashReporter ?? self.crashReporter
            #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            let watchdogLogic = SentryWatchdogTerminationLogic(
                options: options,
                crashAdapter: reporter,
                appStateManager: SentryDependencyContainer.sharedInstance().appStateManager
            )
            return SentryKSCrashIntegrationSessionHandler(
                crashReporter: reporter,
                watchdogTerminationLogic: watchdogLogic,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
            #else
            return SentryKSCrashIntegrationSessionHandler(
                crashReporter: reporter,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
            #endif
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.dateProvider
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAbnormalSession()
        fixture.fileManager.deleteAppHangEvent()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
        fixture.fileManager.deleteAbnormalSession()
        fixture.fileManager.deleteAppHangEvent()
        clearTestState()
    }

    // MARK: - crashedLastLaunch = true

    func testEndCurrentSession_CrashedLastLaunch_EndsSessionAsCrashed() throws {
        // Arrange
        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = true
        crashReporter.internalActiveDurationSinceLastCrash = 5.0

        fixture.dateProvider.setDate(date: Date(timeIntervalSinceReferenceDate: 10))

        // Build the expected crashed session before creating the SUT so the timestamp matches
        let expectedCrashedSession = givenCrashedSession(activeDuration: 5.0, at: Date(timeIntervalSinceReferenceDate: 10))

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        let crashed = try XCTUnwrap(fixture.fileManager.readCrashedSession())
        XCTAssertEqual(SentrySessionStatus.crashed, crashed.status)
        try XCTAssertTrue(expectedCrashedSession.isEqual(to: XCTUnwrap(fixture.fileManager.readCrashedSession())))
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readAbnormalSession())
    }

    func testEndCurrentSession_CrashedLastLaunch_TimestampIsDateMinusActiveDuration() throws {
        // Arrange
        givenCurrentSession()

        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = true
        crashReporter.internalActiveDurationSinceLastCrash = 5.0

        let now = Date(timeIntervalSinceReferenceDate: 100)
        fixture.dateProvider.setDate(date: now)

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        let crashed = try XCTUnwrap(fixture.fileManager.readCrashedSession())
        let expectedTimestamp = now.addingTimeInterval(-5.0)
        let actualTimestamp = try XCTUnwrap(crashed.timestamp)
        XCTAssertEqual(expectedTimestamp.timeIntervalSince1970, actualTimestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - crashedLastLaunch = false, no app hang

    func testEndCurrentSession_NoCrash_SessionRemainsUnchanged() throws {
        // Arrange
        let session = givenCurrentSession()

        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = false

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        let fileManager = fixture.fileManager
        try XCTAssertTrue(session.isEqual(to: XCTUnwrap(fileManager.readCurrentSession())))
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }

    // MARK: - No current session

    func testEndCurrentSession_NoCurrentSession_DoesNothing() {
        // Arrange — no session stored
        let sut = fixture.makeSUT()

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readCrashedSession())
        XCTAssertNil(fixture.fileManager.readAbnormalSession())
    }

    // MARK: - App hang (iOS/tvOS/visionOS only)

#if os(iOS) || os(tvOS)

    func testEndCurrentSession_AppHangEvent_NoCurrentSession_DoesNothing() {
        // Arrange
        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = false

        let appHangEvent = Event()
        fixture.fileManager.storeAppHang(appHangEvent)

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readCrashedSession())
        XCTAssertNil(fixture.fileManager.readAbnormalSession())
    }

    func testEndCurrentSession_AppHangEvent_NoAppHangFileOnDisk_SessionUnchanged() throws {
        // Arrange
        let session = givenCurrentSession()

        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = false

        // No app hang stored
        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        try XCTAssertTrue(session.isEqual(to: XCTUnwrap(fixture.fileManager.readCurrentSession())))
        XCTAssertNil(fixture.fileManager.readCrashedSession())
        XCTAssertNil(fixture.fileManager.readAbnormalSession())
    }

    func testEndCurrentSession_AppHangEventAndCurrentSession_EndsAsAbnormal() throws {
        // Arrange
        let session = givenCurrentSession()

        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = false

        let appHangEvent = Event()
        fixture.fileManager.storeAppHang(appHangEvent)

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readCrashedSession())

        let abnormal = try XCTUnwrap(fixture.fileManager.readAbnormalSession())
        XCTAssertEqual(SentrySessionStatus.abnormal, abnormal.status)
        XCTAssertEqual(session.started.timeIntervalSince1970, abnormal.started.timeIntervalSince1970, accuracy: 0.001)

        let appHangTimestamp = try XCTUnwrap(appHangEvent.timestamp)
        let sessionEndTimestamp = try XCTUnwrap(abnormal.timestamp)
        XCTAssertEqual(appHangTimestamp.timeIntervalSince1970, sessionEndTimestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func testEndCurrentSession_AppHangEventAndCrash_EndsAsCrashed() throws {
        // Arrange
        let crashReporter = fixture.crashReporter
        crashReporter.internalCrashedLastLaunch = true
        crashReporter.internalActiveDurationSinceLastCrash = 5.0

        fixture.dateProvider.setDate(date: Date(timeIntervalSinceReferenceDate: 50))

        let expectedCrashedSession = givenCrashedSession(activeDuration: 5.0, at: Date(timeIntervalSinceReferenceDate: 50))

        let appHangEvent = Event()
        fixture.fileManager.storeAppHang(appHangEvent)

        let sut = fixture.makeSUT(crashReporter: crashReporter)

        // Act
        sut.endCurrentSessionIfRequired()

        // Assert — crash takes priority over app hang
        let crashed = try XCTUnwrap(fixture.fileManager.readCrashedSession())
        XCTAssertEqual(SentrySessionStatus.crashed, crashed.status)
        try XCTAssertTrue(expectedCrashedSession.isEqual(to: XCTUnwrap(fixture.fileManager.readCrashedSession())))
        XCTAssertNil(fixture.fileManager.readCurrentSession())
        XCTAssertNil(fixture.fileManager.readAbnormalSession())
    }

#endif // os(iOS) || os(tvOS)

    // MARK: - Helpers

    @discardableResult
    private func givenCurrentSession() -> SentrySession {
        // serialize sets the timestamp
        let session = SentrySession(jsonObject: fixture.session.serialize())!
        fixture.fileManager.storeCurrentSession(session)
        return session
    }

    /// Stores a current session and returns the same session mutated to crashed state,
    /// mirroring what the handler will write to disk.
    private func givenCrashedSession(activeDuration: TimeInterval, at date: Date) -> SentrySession {
        let session = givenCurrentSession()
        session.endCrashed(withTimestamp: date.addingTimeInterval(-activeDuration))
        return session
    }
}
