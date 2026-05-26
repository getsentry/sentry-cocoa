// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

@objc public enum SentryObjCSpanStatus: UInt {
    case undefined = 0
    case ok
    case deadlineExceeded
    case unauthenticated
    case permissionDenied
    case notFound
    case resourceExhausted
    case invalidArgument
    case unimplemented
    case unavailable
    case internalError
    case unknownError
    case cancelled
    case alreadyExists
    case failedPrecondition
    case aborted
    case outOfRange
    case dataLoss
}

extension SentryObjCSpanStatus {
    init(_ underlying: SentrySpanStatus) {
        self = SentryObjCSpanStatus(rawValue: underlying.rawValue) ?? .undefined
    }
    var underlying: SentrySpanStatus {
        SentrySpanStatus(rawValue: rawValue) ?? .undefined
    }
}

// swiftlint:enable missing_docs
