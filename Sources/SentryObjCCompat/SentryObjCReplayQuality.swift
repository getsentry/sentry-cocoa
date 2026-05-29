// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCReplayQuality: Int {
    case low = 0, medium, high
}

extension SentryObjCReplayQuality {
    init(_ underlying: SentryReplayOptions.SentryReplayQuality) {
        self = SentryObjCReplayQuality(rawValue: underlying.rawValue) ?? .low
    }
    var underlying: SentryReplayOptions.SentryReplayQuality {
        SentryReplayOptions.SentryReplayQuality(rawValue: rawValue) ?? .low
    }
}

// swiftlint:enable missing_docs
