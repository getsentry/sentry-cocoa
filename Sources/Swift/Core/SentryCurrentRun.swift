import Foundation

/// The run of the app process the SDK is running in.
///
/// A run is one launch of the process. The SDK creates the run ID itself, once per process, instead
/// of taking one from the crash handler: the ID has to exist in V9 and V10 alike, before any
/// integration starts and whether or not the crash handler is enabled, because every source that
/// reports how a run ended stores it where it can read it back on a later launch. The crash handler
/// keeps it in its user info, which ends up in the crash report, and the watchdog termination
/// integration keeps it in the app state. Reports that carry the same run ID describe the same run.
/// See decision 41 in `develop-docs/DECISIONS.md`.
@_spi(Private) public final class SentryCurrentRun {

    /// The key under which the crash handlers store the run ID in their user info, which they write
    /// into the `user` section of the crash report.
    public static let userInfoKey = "sentry_run_id"

    /// The ID of the run, a random UUID.
    public let id: String

    convenience init() {
        self.init(id: UUID().uuidString)
    }

    init(id: String) {
        self.id = id
    }

    /// Reads the run ID a crash handler stored in a crash report, or `nil` when the report was
    /// written before the SDK had a run ID.
    ///
    /// SentryCrash and KSCrash both write their user info into the `user` section of the report.
    public static func runId(ofCrashReport report: [AnyHashable: Any]) -> String? {
        guard let user = report["user"] as? [AnyHashable: Any] else {
            return nil
        }
        return user[userInfoKey] as? String
    }
}
