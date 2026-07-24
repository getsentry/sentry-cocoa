#if SDK_V10
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCReplayNetworkBodyCapture: Int {
    case inherit
    case enabled
    case disabled
}

extension SentryObjCReplayNetworkBodyCapture {
    init(_ underlying: SentryReplayOptions.NetworkBodyCapture) {
        switch underlying {
        case .inherit: self = .inherit
        case .enabled: self = .enabled
        case .disabled: self = .disabled
        @unknown default: self = .inherit
        }
    }

    var underlying: SentryReplayOptions.NetworkBodyCapture {
        switch self {
        case .inherit: return .inherit
        case .enabled: return .enabled
        case .disabled: return .disabled
        }
    }
}

// swiftlint:enable missing_docs
#endif // SDK_V10
