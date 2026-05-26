// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

@objc public enum SentryObjCRedactRegionType: Int {
    case redact = 0
    case clipOut
    case clipBegin
    case clipEnd
    case redactSwiftUI
}

extension SentryObjCRedactRegionType {
    init(_ underlying: SentryRedactRegionType) {
        switch underlying {
        case .redact: self = .redact
        case .clipOut: self = .clipOut
        case .clipBegin: self = .clipBegin
        case .clipEnd: self = .clipEnd
        case .redactSwiftUI: self = .redactSwiftUI
        }
    }
    var underlying: SentryRedactRegionType {
        switch self {
        case .redact: return .redact
        case .clipOut: return .clipOut
        case .clipBegin: return .clipBegin
        case .clipEnd: return .clipEnd
        case .redactSwiftUI: return .redactSwiftUI
        }
    }
}

// swiftlint:enable missing_docs
