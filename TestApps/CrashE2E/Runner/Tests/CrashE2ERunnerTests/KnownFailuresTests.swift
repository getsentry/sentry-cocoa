@testable import CrashE2ERunner
import Foundation
import XCTest

final class KnownFailuresTests: XCTestCase {
    func testRunAllowingKnownFailure_whenHarnessTimeoutFails_shouldNeverExemptEitherReporter() {
        // -- Arrange --
        let failures: [Error] = [
            CrashE2EFailure(message: "iOS app did not terminate for scenario: harness-timeout"),
            ReportAssertionFailure(message: "Unexpected report validation")
        ]

        // -- Act & Assert --
        for reporter in Reporter.allCases {
            XCTAssertNil(Scenario.harnessTimeout.knownFailureReason(for: reporter))

            for failure in failures {
                XCTAssertThrowsError(try runAllowingKnownFailure(.harnessTimeout, reporter: reporter, platform: "ios") {
                    throw failure
                }) { error in
                    XCTAssertEqual(String(describing: error), String(describing: failure))
                }
            }
        }
    }

    func testRunAllowingKnownFailure_whenHarnessFails_shouldThrow() {
        // -- Arrange --
        let failure = CrashE2EFailure(message: "simctl launch failed")

        // -- Act & Assert --
        XCTAssertThrowsError(try runAllowingKnownFailure(.objcObject, reporter: .sentryCrash, platform: "ios") {
            throw failure
        }) { error in
            XCTAssertEqual(String(describing: error), failure.message)
        }
    }

    func testRunAllowingKnownFailure_whenFileIOFails_shouldThrow() {
        // -- Arrange --
        let failure = CocoaError(.fileReadNoPermission)

        // -- Act & Assert --
        XCTAssertThrowsError(try runAllowingKnownFailure(.objcObjectAfterCaughtCPP, reporter: .sentryCrash, platform: "macos") {
            throw failure
        }) { error in
            XCTAssertEqual(error as? CocoaError, failure)
        }
    }

    func testRunAllowingKnownFailure_whenKnownReportAssertionFails_shouldSucceed() throws {
        // -- Arrange --
        let scenario = Scenario.objcObject

        // -- Act & Assert --
        XCTAssertNoThrow(try runAllowingKnownFailure(scenario, reporter: .sentryCrash, platform: "ios") {
            try EventAssertions.assert(false, "Expected Objective-C object class in value")
        })
    }

    func testRunAllowingKnownFailure_whenOtherReporterHasReportFailure_shouldThrow() {
        // -- Arrange --
        let scenario = Scenario.objcObject

        // -- Act & Assert --
        XCTAssertThrowsError(try runAllowingKnownFailure(scenario, reporter: .ksCrash, platform: "ios") {
            try EventAssertions.assert(false, "Expected Objective-C object class in value")
        }) { error in
            XCTAssertTrue(error is ReportAssertionFailure)
        }
    }

    func testRunAllowingKnownFailure_whenOtherScenarioHasReportFailure_shouldThrow() {
        // -- Arrange --
        let scenario = Scenario.nsException

        // -- Act & Assert --
        XCTAssertThrowsError(try runAllowingKnownFailure(scenario, reporter: .sentryCrash, platform: "macos") {
            try EventAssertions.assert(false, "Expected NSException type")
        }) { error in
            XCTAssertTrue(error is ReportAssertionFailure)
        }
    }

    func testRunAllowingKnownFailure_whenKnownScenarioPasses_shouldThrow() {
        // -- Arrange --
        let scenario = Scenario.objcObject

        // -- Act & Assert --
        XCTAssertThrowsError(try runAllowingKnownFailure(scenario, reporter: .sentryCrash, platform: "ios") {}) { error in
            XCTAssertTrue(String(describing: error).contains("passed unexpectedly"))
        }
    }

    func testRunAllowingKnownFailure_whenUnlistedScenarioPasses_shouldSucceed() throws {
        // -- Arrange --
        let scenario = Scenario.objcObject

        // -- Act & Assert --
        XCTAssertNoThrow(try runAllowingKnownFailure(scenario, reporter: .ksCrash, platform: "ios") {})
    }
}
