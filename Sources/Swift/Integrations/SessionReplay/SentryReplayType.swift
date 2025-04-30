import Foundation

@objc
enum SentryReplayType: Int {
    case session
    case buffer
}

// Implementing the CustomStringConvertible protocol to provide a string representation of the enum values.
// This method will be called by the Swift runtime when converting the enum to a string, i.e. in String interpolations.
extension SentryReplayType: CustomStringConvertible {
    var description: String {
        return toString()
    }
}

extension SentryReplayType {
    func toString() -> String {
        switch self {
            case .buffer: return "buffer"
            case .session:  return "session"
        }
    }
}
