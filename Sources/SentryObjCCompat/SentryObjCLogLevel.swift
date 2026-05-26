// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

@objc public enum SentryObjCLogLevel: Int {
    case trace = 0, debug, info, warn, error, fatal
}

extension SentryObjCLogLevel {
    init(_ underlying: SentryLog.Level) {
        self = SentryObjCLogLevel(rawValue: underlying.rawValue) ?? .trace
    }
    var underlying: SentryLog.Level {
        SentryLog.Level(rawValue: rawValue) ?? .trace
    }
}

// swiftlint:enable missing_docs
