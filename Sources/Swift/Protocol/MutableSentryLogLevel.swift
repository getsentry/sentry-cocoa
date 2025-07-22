@_implementationOnly import _SentryPrivate
import Foundation

@objc
public enum MutableSentryLogLevel: Int {
    case trace
    case debug
    case info
    case warn
    case error
    case fatal
    
    // Convert from Swift SentryLog.Level
    internal static func from(_ level: SentryLog.Level) -> MutableSentryLogLevel {
        switch level {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .warn: return .warn
        case .error: return .error
        case .fatal: return .fatal
        }
    }
    
    // Convert to Swift SentryLog.Level
    internal func toLevel() -> SentryLog.Level {
        switch self {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .warn: return .warn
        case .error: return .error
        case .fatal: return .fatal
        @unknown default: return .error
        }
    }
    
    // Get severity number for this level
    internal func toSeverityNumber() -> Int {
        switch self {
        case .trace: return 1
        case .debug: return 5
        case .info: return 9
        case .warn: return 13
        case .error: return 17
        case .fatal: return 21
        @unknown default: return 17 // Default to error level
        }
    }
}
