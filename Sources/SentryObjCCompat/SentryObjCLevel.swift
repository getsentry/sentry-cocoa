// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc public enum SentryObjCLevel: UInt {
    case none = 0, debug, info, warning, error, fatal
}

extension SentryObjCLevel {
    init(_ underlying: SentryLevel) {
        self = SentryObjCLevel(rawValue: underlying.rawValue) ?? .none
    }
    var underlying: SentryLevel {
        SentryLevel(rawValue: rawValue) ?? .none
    }
}

// swiftlint:enable missing_docs
