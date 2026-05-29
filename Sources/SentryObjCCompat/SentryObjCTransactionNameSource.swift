// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCTransactionNameSource: Int {
    case custom = 0, url, route, view, component, task
}

extension SentryObjCTransactionNameSource {
    init(_ underlying: SentryTransactionNameSource) {
        self = SentryObjCTransactionNameSource(rawValue: underlying.rawValue) ?? .custom
    }
    var underlying: SentryTransactionNameSource {
        SentryTransactionNameSource(rawValue: rawValue) ?? .custom
    }
}

// swiftlint:enable missing_docs
