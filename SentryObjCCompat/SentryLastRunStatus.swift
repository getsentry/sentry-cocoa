internal import SentrySwift
import Foundation

/// Crash status of the previous program execution.
///
/// Raw values match `Sentry.SentryLastRunStatus`.
@objc(SOCSentryLastRunStatus)
public enum SentryLastRunStatus: Int {
    case unknown = 0
    case didNotCrash = 1
    case didCrash = 2
}

extension SentryLastRunStatus {
    init(_ underlying: SentrySwift.SentryLastRunStatus) {
        self = SentryLastRunStatus(rawValue: underlying.rawValue) ?? .unknown
    }
}
