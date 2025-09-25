import Logging
import Sentry

public struct SentryLogHandler: LogHandler {
    
    public var metadata = Logger.Metadata()
    
    public var logLevel: Logger.Level
    
    private let sentryLogger: SentryLogger
    
    public init(logLevel: Logger.Level = .info) {
        self.init(logLevel: logLevel, sentryLogger: SentrySDK.logger)
    }
    
    init(logLevel: Logger.Level, sentryLogger: SentryLogger) {
        self.logLevel = logLevel
        self.sentryLogger = SentrySDK.logger
    }
    
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        var attributes: [String: Any] = [:]
        attributes["swift-log.source"] = source
        attributes["swift-log.file"] = file
        attributes["swift-log.function"] = function
        attributes["swift-log.line"] = line
        
        let allMetadata = mergeMetadata(self.metadata, metadata)
        for (key, value) in allMetadata {
            attributes["swift-log.metadata.\(key)"] = convertMetadataValue(value)
        }
        
        // Call the appropriate SentryLog method based on level
        let messageString = String(describing: message)
        switch mapLogLevel(level) {
        case .trace:
            sentryLogger.trace(messageString, attributes: attributes)
        case .debug:
            sentryLogger.debug(messageString, attributes: attributes)
        case .info:
            sentryLogger.info(messageString, attributes: attributes)
        case .warn:
            sentryLogger.warn(messageString, attributes: attributes)
        case .error:
            sentryLogger.error(messageString, attributes: attributes)
        case .fatal:
            sentryLogger.fatal(messageString, attributes: attributes)
        @unknown default:
            sentryLogger.fatal(messageString, attributes: attributes)
        }
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Maps Swift Log levels to SentryLog levels
    private func mapLogLevel(_ level: Logger.Level) -> SentryLog.Level {
        switch level {
        case .trace:
            return .trace
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .info  // Map notice to info as SentryLog doesn't have notice
        case .warning:
            return .warn
        case .error:
            return .error
        case .critical:
            return .fatal
        }
    }
    
    /// Merges handler metadata with provided metadata
    private func mergeMetadata(_ handlerMetadata: Logger.Metadata, _ providedMetadata: Logger.Metadata?) -> Logger.Metadata {
        var merged = handlerMetadata
        if let provided = providedMetadata {
            for (key, value) in provided {
                merged[key] = value
            }
        }
        return merged
    }
    
    /// Converts Swift Log metadata values to Any for SentryLog attributes
    private func convertMetadataValue(_ value: Logger.Metadata.Value) -> Any {
        switch value {
        case .string(let string):
            return string
        case .stringConvertible(let convertible):
            return String(describing: convertible)
        case .dictionary(let dict):
            return dict.mapValues { convertMetadataValue($0) }
        case .array(let array):
            return array.map { convertMetadataValue($0) }
        }
    }
}
