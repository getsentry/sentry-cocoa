// swiftlint:disable missing_docs
import Foundation

extension SentrySessionEndStatus {
    var name: String {
        switch self {
        case .exited: return "exited"
        case .crashed: return "crashed"
        case .abnormal: return "abnormal"
        case .unhandled: return "unhandled"
        @unknown default: return "unknown"
        }
    }

    init?(name: String) {
        switch name {
        case "exited": self = .exited
        case "crashed": self = .crashed
        case "abnormal": self = .abnormal
        case "unhandled": self = .unhandled
        default: return nil
        }
    }
}

// swiftlint:enable missing_docs
