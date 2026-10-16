import Foundation

extension Scenario {
    /// Scenarios that currently fail for a reporter because of a documented SDK gap.
    ///
    /// CI runs every default scenario, so a known failure must keep failing: once the gap is
    /// closed the scenario passes unexpectedly, the run fails, and the entry has to be removed.
    func knownFailureReason(for reporter: Reporter) -> String? {
        switch (reporter, self) {
        case (.sentryCrash, .objcObject), (.sentryCrash, .objcObjectAfterCaughtCPP):
            // These run with C++ V2 enabled and strict modern-backend assertions, which the
            // SentryCrash C++ monitor does not meet for thrown Objective-C objects.
            return "SentryCrash does not report thrown Objective-C objects with the modern report shape"
        default:
            return nil
        }
    }
}

/// Accepts only report assertion failures for a listed SDK gap. Harness failures always
/// propagate. Callers must finish process cleanup before passing a failed outcome here.
func runAllowingKnownFailure(_ scenario: Scenario, reporter: Reporter, platform: String,
                             _ body: () throws -> Void) throws {
    guard let reason = scenario.knownFailureReason(for: reporter) else {
        try body()
        return
    }

    do {
        try body()
    } catch let error as ReportAssertionFailure {
        log("⚠️ \(platform)/\(scenario.rawValue) failed as expected (\(reason)): \(error)")
        return
    }
    try fail(
        "Known failure passed unexpectedly (\(reason)). "
            + "Remove \(scenario.rawValue) from Scenario.knownFailureReason(for:)."
    )
}
