import Foundation

extension SentryLogLevel: Codable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        
        switch stringValue {
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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid SentryLogLevel string value: '\(stringValue)'. Expected one of: trace, debug, info, warn, error, fatal"
            )
        }
    }
}
