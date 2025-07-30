extension SentryLog {
    @objc(SentryStructuredLogLevel)
    public enum Level: Int, Codable {
        case trace
        case debug
        case info
        case warn
        case error
        case fatal
        
        public init(value: String) throws {
            switch value {
            case "trace":
                self = .trace
            case "debug":
                self = .debug
            case "info":
                self = .info
            case "warn":
                self = .warn
            case "error":
                self = .error
            case "fatal":
                self = .fatal
            default:
                throw NSError(domain: "SentryLogLevel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown log level: \(value)"])
            }
        }
        
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
        
        // Docs: https://develop.sentry.dev/sdk/telemetry/logs/#log-severity-number
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
        
        // Custom Codable implementation to encode/decode as strings
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(String.self)
            self = try .init(value: stringValue)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }
}
