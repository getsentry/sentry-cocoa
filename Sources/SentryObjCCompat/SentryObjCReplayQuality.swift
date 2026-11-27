// swiftlint:disable missing_docs
internal import Sentry
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
