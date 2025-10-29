import CocoaLumberjackSwift
import Sentry

/// A CocoaLumberjack logger that forwards log entries to Sentry's structured logging system.
///
/// `SentryCocoaLumberjackLogger` implements CocoaLumberjack's `DDAbstractLogger` protocol, allowing you
/// to integrate Sentry's structured logging capabilities with CocoaLumberjack. This enables you to capture
/// application logs from CocoaLumberjack and send them to Sentry for analysis and monitoring.
///
/// ## Level Filtering
/// The logger supports filtering by log level. Only logs at or above the configured `logLevel` will be
/// sent to Sentry. Defaults to `.info`.
///
/// ## Level Mapping
/// CocoaLumberjack log levels are mapped to Sentry log levels:
/// - `.error` → `.error`
/// - `.warning` → `.warn`
/// - `.info` → `.info`
/// - `.debug` → `.debug`
/// - `.verbose` → `.trace`
///
/// ## Usage
/// ```swift
/// import CocoaLumberjackSwift
/// import Sentry
/// import SentryCocoaLumberjack
///
/// // Initialize Sentry SDK
/// SentrySDK.start { options in
///     options.dsn = "YOUR_DSN"
/// }
///
/// // Add SentryCocoaLumberjackLogger to CocoaLumberjack
/// // Only logs at .info level and above will be sent to Sentry
/// DDLog.add(SentryCocoaLumberjackLogger(logLevel: .info))
///
/// // Use CocoaLumberjack as usual
/// DDLogInfo("User logged in")
/// DDLogError("Payment failed")
/// ```
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/).
/// - Warning: This logger requires Sentry SDK to be initialized before use.
public class SentryCocoaLumberjackLogger: DDAbstractLogger {
    
    private let sentryLogger: SentryLogger
    
    /// The minimum log level for messages to be sent to Sentry.
    ///
    /// Messages below this level will be filtered out and not sent to Sentry.
    /// Defaults to `.info`.
    public var logLevel: DDLogLevel
    
    /// Creates a new SentryCocoaLumberjackLogger instance.
    ///
    /// - Parameter logLevel: The minimum log level for messages to be sent to Sentry.
    ///   Defaults to `.info`.
    /// - Note: Make sure to initialize the Sentry SDK before creating this logger.
    public init(logLevel: DDLogLevel = .info) {
        self.sentryLogger = SentrySDK.logger
        self.logLevel = logLevel
        super.init()
    }
    
    init(logLevel: DDLogLevel = .info, sentryLogger: SentryLogger) {
        self.sentryLogger = sentryLogger
        self.logLevel = logLevel
        super.init()
    }
    
    /// Logs a message from CocoaLumberjack to Sentry.
    ///
    /// - Parameter logMessage: The log message from CocoaLumberjack containing the message, level, and metadata.
    public override func log(message logMessage: DDLogMessage) {
        guard logMessage.level.rawValue <= logLevel.rawValue else {
            return
        }
        
        var attributes: [String: Any] = [:]
        attributes["sentry.origin"] = "auto.logging.cocoalumberjack"
        
        attributes["cocoalumberjack.level"] = logFlagToString(logMessage.flag)
        attributes["cocoalumberjack.file"] = logMessage.file
        attributes["cocoalumberjack.function"] = logMessage.function ?? ""
        attributes["cocoalumberjack.line"] = String(logMessage.line)
        attributes["cocoalumberjack.context"] = String(logMessage.context)
        attributes["cocoalumberjack.timestamp"] = logMessage.timestamp.timeIntervalSince1970
        attributes["cocoalumberjack.threadID"] = String(logMessage.threadID)
        
        if let threadName = logMessage.threadName, !threadName.isEmpty {
            attributes["cocoalumberjack.threadName"] = threadName
        }
        
        if !logMessage.queueLabel.isEmpty {
            attributes["cocoalumberjack.queueLabel"] = logMessage.queueLabel
        }

        forwardToSentry(message: logMessage.message, flag: logMessage.flag, attributes: attributes)
    }
    
    private func forwardToSentry(message: String, flag: DDLogFlag, attributes: [String: Any]) {
        if flag.contains(.error) {
            sentryLogger.error(message, attributes: attributes)
        } else if flag.contains(.warning) {
            sentryLogger.warn(message, attributes: attributes)
        } else if flag.contains(.info) {
            sentryLogger.info(message, attributes: attributes)
        } else if flag.contains(.debug) {
            sentryLogger.debug(message, attributes: attributes)
        } else if flag.contains(.verbose) {
            sentryLogger.trace(message, attributes: attributes)
        } else {
            sentryLogger.info(message, attributes: attributes)
        }
    }

    private func logFlagToString(_ flag: DDLogFlag) -> String {
        if flag.contains(.error) {
            return "error"
        } else if flag.contains(.warning) {
            return "warning"
        } else if flag.contains(.info) {
            return "info"
        } else if flag.contains(.debug) {
            return "debug"
        } else if flag.contains(.verbose) {
            return "verbose"
        } else {
            return "unknown"
        }
    }
}
