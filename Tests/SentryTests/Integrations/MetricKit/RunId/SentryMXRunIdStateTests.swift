@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if (os(iOS) || os(macOS)) && compiler(>=6.4)
import MetricKit
import StateReporting

final class SentryMXRunIdStateTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("Reported states require iOS 27 or macOS 27")
        }
    }

    func testMetadataDictionary_shouldHoldTheRunId() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let sut = SentryMXRunIdState.Metadata(runId: SentryCurrentRun.ID(rawValue: "run-1"))

        // -- Act --
        let metadata = sut.metadataDictionary

        // -- Assert --
        XCTAssertEqual(metadata, ["run_id": .string("run-1")])
    }

    func testReport_whenCalledTwiceForTheSameRun_shouldNotCrash() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // The system gives no way to read a reported state back, so this only covers that
        // reporting, and reporting again as an SDK restart does, is safe.

        // -- Arrange --
        let runId = SentryCurrentRun.ID(rawValue: "run-1")

        // -- Act & Assert --
        SentryMXRunIdState.report(runId: runId)
        SentryMXRunIdState.report(runId: runId)
    }

    func testRunId_whenStatesHoldTheStateOfOneRun_shouldReturnItsRunId() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-1")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertEqual(runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenStatesAreEmpty_shouldReturnNil() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Act --
        let runId = SentryMXRunIdState.runId(of: [])

        // -- Assert --
        XCTAssertNil(runId)
    }

    func testRunId_whenStatesBelongToOtherDomains_shouldReturnNil() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "com.example.checkout", metadata: ["run_id": .string("run-1")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertNil(runId)
    }

    func testRunId_whenTheAppReportsStatesToo_shouldReturnTheRunIdOfTheSDKState() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "com.example.checkout", metadata: ["run_id": .string("other")]),
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-1")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertEqual(runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenTheSameRunIsListedTwice_shouldReturnItsRunId() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-1")]),
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-1")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertEqual(runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenStatesHoldTheStatesOfSeveralRuns_shouldReturnNil() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-1")]),
            (domain: "io.sentry.run", metadata: ["run_id": .string("run-2")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertNil(runId)
    }

    func testRunId_whenTheRunIdIsNotAString_shouldReturnNil() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "io.sentry.run", metadata: ["run_id": .integer(1)])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertNil(runId)
    }

    func testRunId_whenTheStateHasNoRunId_shouldReturnNil() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        // -- Arrange --
        let states = try givenStates([
            (domain: "io.sentry.run", metadata: ["other": .string("run-1")]),
            (domain: "io.sentry.run", metadata: ["run_id": .string("")])
        ])

        // -- Act --
        let runId = SentryMXRunIdState.runId(of: states)

        // -- Assert --
        XCTAssertNil(runId)
    }

    // MARK: - Helpers

    /// `ReportedState` has no public initializer, so states are decoded from the JSON format of
    /// its `Codable` conformance.
    @available(iOS 27.0, macOS 27.0, *)
    private func givenStates(
        _ states: [(domain: String, metadata: [String: ReportableMetadataValue])]
    ) throws -> [MetricManager.ReportedState] {
        let json = try states.map { state -> [String: Any] in
            [
                "domain": state.domain,
                "label": "run",
                "duration": ["value": 12.0, "unit": UnitDuration.seconds.symbol],
                "stableMetadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state.metadata))
            ]
        }
        return try JSONDecoder().decode([MetricManager.ReportedState].self, from: JSONSerialization.data(withJSONObject: json))
    }
}

#endif // (os(iOS) || os(macOS)) && compiler(>=6.4)
