// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCLastRunStatus: Int {
    case unknown = 0, didNotCrash, didCrash
}

extension SentryObjCLastRunStatus {
    init(_ underlying: SentryLastRunStatus) {
        self = SentryObjCLastRunStatus(rawValue: underlying.rawValue) ?? .unknown
    }
    var underlying: SentryLastRunStatus {
        SentryLastRunStatus(rawValue: rawValue) ?? .unknown
    }
}

// swiftlint:enable missing_docs
