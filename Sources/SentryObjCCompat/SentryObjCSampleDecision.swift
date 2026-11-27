// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc public enum SentryObjCSampleDecision: UInt {
    case undecided = 0, yes, no
}

extension SentryObjCSampleDecision {
    init(_ underlying: SentrySampleDecision) {
        self = SentryObjCSampleDecision(rawValue: underlying.rawValue) ?? .undecided
    }
    var underlying: SentrySampleDecision {
        SentrySampleDecision(rawValue: rawValue) ?? .undecided
    }
}

// swiftlint:enable missing_docs
