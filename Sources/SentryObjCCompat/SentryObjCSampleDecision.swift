// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

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
