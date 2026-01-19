import Logging
import Sentry

/// A `swift-log` handler that forwards log entries to Sentry's structured logging system.
///
/// `SentryLogHandler` implements the `swift-log` `LogHandler` protocol, allowing you to integrate
/// Sentry's structured logging capabilities with Swift's standard logging framework. This enables
/// you to capture application logs and send them to Sentry for analysis and monitoring.
///
/// ## Level Mapping
/// `swift-log` levels are mapped to Sentry log levels:
/// - `.trace` → `.trace`
/// - `.debug` → `.debug`
/// - `.info` → `.info`
/// - `.notice` → `.info` (notice maps to info as SentryLog doesn't have notice)
/// - `.warning` → `.warn`
/// - `.error` → `.error`
/// - `.critical` → `.fatal`
///
/// ## Usage
/// ```swift
/// import Logging
/// import Sentry
///
/// // Initialize Sentry SDK
/// SentrySDK.start { options in
///     options.dsn = "YOUR_DSN"
/// }
///
/// // Register SentryLogHandler
/// LoggingSystem.bootstrap { _ in
///     return SentryLogHandler(logLevel: .trace)
/// }
///
/// // Create & use the logger
/// let logger = Logger(label: "com.example.app")
/// logger.info("User logged in", metadata: ["userId": "12345"])
/// logger.error("Payment failed", metadata: ["errorCode": 500])
/// ```
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/).
/// - Warning: This handler requires Sentry SDK to be initialized before use.
public struct SentryLogHandler: LogHandler {
    
    /// Logger metadata that will be included with all log entries.
    ///
    /// This metadata is merged with any metadata provided at the call site,
    /// with call-site metadata taking precedence over handler metadata.
    public var metadata = Logger.Metadata()
    
    /// The minimum log level for messages to be sent to Sentry.
    ///
    /// Messages below this level will be filtered out and not sent to Sentry.
    /// Defaults to `.info`.
    public var logLevel: Logger.Level
    
    /// Creates a new SentryLogHandler with the specified log level.
    ///
    /// - Parameter logLevel: The minimum log level for messages to be sent to Sentry.
    ///   Defaults to `.info`.
    public init(logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
    }
    
    /// Logs a message to Sentry.
    ///
    /// - Parameters:
    ///   - level: The severity level of the log entry.
    ///   - message: The message to log.
    ///   - metadata: The metadata to add to the log entry.
    ///   - source: The source of the log entry.
    ///   - file: The file the log entry was logged from.
    ///   - function: The function the log entry was logged from.
    ///   - line: The line the log entry was logged from.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard SentrySDK.isEnabled else {
            return
        }
        
        // Filter out messages below the configured log level threshold
        guard level >= self.logLevel else {
            return
        }
        
        var attributes: [String: Any] = [:]
        attributes["sentry.origin"] = "auto.logging.swift-log"
        attributes["swift-log.level"] = level.rawValue
        attributes["swift-log.source"] = source
        attributes["code.file.path"] = file
        attributes["code.function.name"] = function
        attributes["code.line.number"] = Int(line)
        
        let allMetadata = self.metadata.merging(metadata ?? [:]) { _, new in
            new
        }
        for (key, value) in allMetadata {
            attributes["swift-log.\(key)"] = "\(value)"
        }
        
        // Call the appropriate SentryLog method based on level
        let messageString = String(describing: message)
        let logger = SentrySDK.logger
        
        switch level {
        case .trace:
            logger.trace(messageString, attributes: attributes)
        case .debug:
            logger.debug(messageString, attributes: attributes)
        case .info:
            logger.info(messageString, attributes: attributes)
        case .notice:
            // Map notice to info as SentryLog doesn't have notice
            logger.info(messageString, attributes: attributes)
        case .warning:
            logger.warn(messageString, attributes: attributes)
        case .error:
            logger.error(messageString, attributes: attributes)
        case .critical:
            logger.fatal(messageString, attributes: attributes)
        }
    }
    
    /// Subscript to access and set metadata.
    ///
    /// - Parameters:
    ///   - metadataKey: The key of the metadata to access or set.
    /// - Returns: The value of the metadata.
    /// - Sets: The value of the metadata.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }
}
