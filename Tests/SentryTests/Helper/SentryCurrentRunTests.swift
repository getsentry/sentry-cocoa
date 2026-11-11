#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryCurrentRunTests: XCTestCase {

    func testInit_shouldCreateUUID() throws {
        // -- Act --
        let sut = SentryCurrentRun()

        // -- Assert --
        XCTAssertNotNil(UUID(uuidString: sut.id.rawValue))
    }

    func testInit_whenCalledTwice_shouldCreateDifferentIds() {
        // -- Act --
        let first = SentryCurrentRun()
        let second = SentryCurrentRun()

        // -- Assert --
        XCTAssertNotEqual(first.id, second.id)
    }

    func testDependencies_shouldKeepOneRunPerProcess() {
        // -- Act --
        let first = Dependencies.currentRun
        let second = Dependencies.currentRun

        // -- Assert --
        XCTAssertEqual(first.id, second.id)
    }

    func testRunIdOfCrashReport_whenUserSectionHasRunId_shouldReturnIt() {
        // -- Arrange --
        let report: [AnyHashable: Any] = [
            "user": [SentryCurrentRun.userInfoKey: "run-id", "release": "1.0.0"]
        ]

        // -- Act --
        let runId = SentryCurrentRun.runId(ofCrashReport: report)

        // -- Assert --
        XCTAssertEqual(runId, SentryCurrentRun.ID(rawValue: "run-id"))
    }

    func testRunIdOfCrashReport_whenUserSectionHasNoRunId_shouldReturnNil() {
        // -- Arrange --
        let report: [AnyHashable: Any] = ["user": ["release": "1.0.0"]]

        // -- Act & Assert --
        XCTAssertNil(SentryCurrentRun.runId(ofCrashReport: report))
    }

    func testRunIdOfCrashReport_whenRunIdIsNotAString_shouldReturnNil() {
        // -- Arrange --
        let report: [AnyHashable: Any] = ["user": [SentryCurrentRun.userInfoKey: 7]]

        // -- Act & Assert --
        XCTAssertNil(SentryCurrentRun.runId(ofCrashReport: report))
    }

    func testRunIdOfCrashReport_whenReportHasNoUserSection_shouldReturnNil() {
        // -- Arrange --
        let report: [AnyHashable: Any] = ["system": ["process_id": 7]]

        // -- Act & Assert --
        XCTAssertNil(SentryCurrentRun.runId(ofCrashReport: report))
    }
}
