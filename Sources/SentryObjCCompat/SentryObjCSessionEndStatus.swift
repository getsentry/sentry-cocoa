// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCSessionEndStatus: UInt {
    case exited = 0, crashed, abnormal, unhandled
}
 
extension SentryObjCSessionEndStatus {
    var underlying: SentrySessionEndStatus? {
        SentrySessionEndStatus(rawValue: rawValue)
    }
}

// swiftlint:enable missing_docs
