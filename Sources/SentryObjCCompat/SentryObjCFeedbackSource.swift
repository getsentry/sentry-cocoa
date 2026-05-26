// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCFeedbackSource: Int {
    case widget = 0, custom
}

extension SentryObjCFeedbackSource {
    init(_ underlying: SentryFeedback.SentryFeedbackSource) {
        self = SentryObjCFeedbackSource(rawValue: underlying.rawValue) ?? .widget
    }
    var underlying: SentryFeedback.SentryFeedbackSource {
        SentryFeedback.SentryFeedbackSource(rawValue: rawValue) ?? .widget
    }
}

// swiftlint:enable missing_docs
