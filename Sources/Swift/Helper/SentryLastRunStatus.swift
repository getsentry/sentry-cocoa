import Foundation

/// Represents the crash status of the last program execution.
///
/// Use ``SentrySDK/lastRunStatus`` to check if the previous app execution
/// terminated with a crash. Before the SDK is fully initialized, the status
/// is ``unknown`` because the crash reporter hasn't loaded its state yet.
///
/// - note: This enum replaces the `crashedLastRun` boolean property, which
///   could not distinguish between "did not crash" and "not yet known."
@objc public enum SentryLastRunStatus: Int {
    /// The SDK hasn't determined the crash status yet.
    ///
    /// This is the value returned before ``SentrySDK/start(configureOptions:)``
    /// finishes initializing the crash reporter.
    case unknown = 0

    /// The last program execution did **not** end with a crash.
    case didNotCrash = 1

    /// The last program execution ended with a crash.
    case didCrash = 2

}

extension SentryLastRunStatus: CustomStringConvertible {
    /// A human-readable representation of the status, matching the case name.
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .didNotCrash: return "didNotCrash"
        case .didCrash: return "didCrash"
        }
    }
}
