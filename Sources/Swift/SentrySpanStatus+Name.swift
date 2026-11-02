import Foundation

extension SentrySpanStatus {
    /// Wire value for this status, such as `ok` or `deadline_exceeded`.
    public var name: String {
        switch self {
        case .undefined:
            return "undefined"
        case .ok:
            return "ok"
        case .deadlineExceeded:
            return "deadline_exceeded"
        case .unauthenticated:
            return "unauthenticated"
        case .permissionDenied:
            return "permission_denied"
        case .notFound:
            return "not_found"
        case .resourceExhausted:
            return "resource_exhausted"
        case .invalidArgument:
            return "invalid_argument"
        case .unimplemented:
            return "unimplemented"
        case .unavailable:
            return "unavailable"
        case .internalError:
            return "internal_error"
        case .unknownError:
            return "unknown_error"
        case .cancelled:
            return "cancelled"
        case .alreadyExists:
            return "already_exists"
        case .failedPrecondition:
            return "failed_precondition"
        case .aborted:
            return "aborted"
        case .outOfRange:
            return "out_of_range"
        case .dataLoss:
            return "data_loss"
        @unknown default:
            return "undefined"
        }
    }
}

/// Objective-C entry point for `SentrySpanStatus.name`. A Swift extension on the
/// enum is not visible to Objective-C, and this is not a public type.
@used
@_cdecl("sentry_spanStatusName")
func sentry_spanStatusName(_ rawValue: UInt) -> NSString {
    (SentrySpanStatus(rawValue: rawValue) ?? .undefined).name as NSString
}
