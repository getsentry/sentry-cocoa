// swiftlint:disable missing_docs
import Foundation

@objc
@_spi(Private) public enum SentryReplayType: Int {
    case session
    case buffer
}

extension SentryReplayType {
    init?(crashReplayType: UInt32) {
        // Zero means the type was unavailable in legacy crash-info files.
        guard crashReplayType > 0 else { return nil }
        self.init(rawValue: Int(crashReplayType) - 1)
    }

    var crashReplayType: UInt32 {
        UInt32(rawValue + 1)
    }

    func toString() -> String {
        switch self {
            case .buffer: return "buffer"
            case .session:  return "session"
        }
    }
}

// Implementing the CustomStringConvertible protocol to provide a string representation of the enum values.
// This method will be called by the Swift runtime when converting the enum to a string, i.e. in String interpolations.
extension SentryReplayType: CustomStringConvertible {
    public var description: String {
        return toString()
    }
}
// swiftlint:enable missing_docs
