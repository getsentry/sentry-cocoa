// swiftlint:disable missing_docs
#if os(iOS) || os(macOS)
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCProfileLifecycle: Int {
    case manual = 0
    case trace = 1
}

extension SentryObjCProfileLifecycle {
    init(_ underlying: SentryProfileOptions.SentryProfileLifecycle) {
        self = SentryObjCProfileLifecycle(rawValue: underlying.rawValue) ?? .manual
    }

    var underlying: SentryProfileOptions.SentryProfileLifecycle {
        SentryProfileOptions.SentryProfileLifecycle(rawValue: rawValue) ?? .manual
    }
}

#endif // os(iOS) || os(macOS)
// swiftlint:enable missing_docs
