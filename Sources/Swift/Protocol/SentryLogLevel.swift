@objc
public enum SentryLogLevel: Int {
    case trace
    case debug
    case info
    case warn
    case error
    case fatal
    
    public var value: String {
        switch self {
        case .trace:
            return "trace"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .warn:
            return "warn"
        case .error:
            return "error"
        case .fatal:
            return "fatal"
        }
    }
    
    public func toSeverityNumber() -> Int {
        switch self {
        case .trace:
            return 1
        case .debug:
            return 5
        case .info:
            return 9
        case .warn:
            return 13
        case .error:
            return 17
        case .fatal:
            return 21
        }
    }
}
