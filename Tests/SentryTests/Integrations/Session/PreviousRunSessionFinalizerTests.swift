@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

/// Covers how `PreviousRunSessionFinalizer` tells the previous run recorder how the run ended.
final class PreviousRunSessionFinalizerTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnForTestCase(type: PreviousRunSessionFinalizerTests.self)

    private var fileManager: TestFileManager!
    private var recorder: TestPreviousRunRecorder!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsnAsString
        fileManager = try TestFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        fileManager.deleteCurrentSession()
        recorder = TestPreviousRunRecorder()
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testFinalizeIfNeeded_whenPreviousRunCrashedWithoutSession_shouldRecordCrash() {
        // -- Arrange --
        let sut = givenSut(crashedLastLaunch: true)

        // -- Act --
        sut.finalizeIfNeeded()

        // -- Assert --
        XCTAssertEqual(recorder.invocations, [TestPreviousRunRecorder.Invocation(crashed: true, watchdogTerminated: false)])
    }

    func testFinalizeIfNeeded_whenPreviousRunDidNotCrash_shouldRecordRun() {
        // -- Arrange --
        let sut = givenSut(crashedLastLaunch: false)

        // -- Act --
        sut.finalizeIfNeeded()

        // -- Assert --
        XCTAssertEqual(recorder.invocations, [TestPreviousRunRecorder.Invocation(crashed: false, watchdogTerminated: false)])
    }

    func testFinalizeIfNeeded_whenPreviousRunCrashedWithSession_shouldRecordCrashAndEndSession() throws {
        // -- Arrange --
        fileManager.storeCurrentSession(SentrySession(releaseName: "1.0.0", distinctId: "some-id"))
        let sut = givenSut(crashedLastLaunch: true)

        // -- Act --
        sut.finalizeIfNeeded()

        // -- Assert --
        XCTAssertEqual(recorder.invocations, [TestPreviousRunRecorder.Invocation(crashed: true, watchdogTerminated: false)])
        XCTAssertNotNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readCurrentSession())
    }

    // MARK: - Helpers

    private func givenSut(crashedLastLaunch: Bool) -> PreviousRunSessionFinalizer {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        PreviousRunSessionFinalizer(
            crashedLastLaunch: crashedLastLaunch,
            activeDurationSinceLastCrash: 0,
            watchdogTerminationLogic: nil,
            fileManager: fileManager,
            dateProvider: TestCurrentDateProvider(),
            previousRunRecorder: recorder
        )
        #else
        PreviousRunSessionFinalizer(
            crashedLastLaunch: crashedLastLaunch,
            activeDurationSinceLastCrash: 0,
            fileManager: fileManager,
            dateProvider: TestCurrentDateProvider(),
            previousRunRecorder: recorder
        )
        #endif
    }
}

private final class TestPreviousRunRecorder: SentryPreviousRunRecorder {
    struct Invocation: Equatable {
        let crashed: Bool
        let watchdogTerminated: Bool
    }

    private(set) var invocations: [Invocation] = []

    func recordPreviousRun(crashed: Bool, watchdogTerminated: Bool) {
        invocations.append(Invocation(crashed: crashed, watchdogTerminated: watchdogTerminated))
    }
}
