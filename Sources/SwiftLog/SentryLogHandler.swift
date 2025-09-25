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
/// // Crea & use the logger
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
    
    private let sentryLogger: SentryLogger
    
    /// Creates a new SentryLogHandler with the specified log level.
    ///
    /// - Parameter logLevel: The minimum log level for messages to be sent to Sentry.
    ///   Defaults to `.info`.
    public init(logLevel: Logger.Level = .info) {
        self.init(logLevel: logLevel, sentryLogger: SentrySDK.logger)
    }
    
    init(logLevel: Logger.Level, sentryLogger: SentryLogger) {
        self.logLevel = logLevel
        self.sentryLogger = sentryLogger
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
        attributes["sentry.origin"] = "auto.logging.swift-log"
        attributes["swift-log.level"] = level.rawValue
        attributes["swift-log.source"] = source
        attributes["swift-log.file"] = file
        attributes["swift-log.function"] = function
        attributes["swift-log.line"] = line
        
        let allMetadata = self.metadata.merging(metadata ?? [:]) { _, new in
            new
        }
        for (key, value) in allMetadata {
            attributes["swift-log.\(key)"] = "\(value)"
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
}
