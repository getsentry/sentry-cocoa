import CocoaLumberjackSwift
import Sentry

/// A CocoaLumberjack logger that forwards log entries to Sentry's structured logging system.
///
/// `SentryCocoaLumberjackLogger` implements CocoaLumberjack's `DDAbstractLogger` protocol, allowing you
/// to integrate Sentry's structured logging capabilities with CocoaLumberjack. This enables you to capture
/// application logs from CocoaLumberjack and send them to Sentry for analysis and monitoring.
///
/// ## Level Filtering
/// Use CocoaLumberjack's built-in filtering API when adding the logger:
/// ```swift
/// DDLog.add(SentryCocoaLumberjackLogger(), with: .info)
/// ```
/// This ensures only logs at or above the specified level are sent to Sentry.
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
/// DDLog.add(SentryCocoaLumberjackLogger(), with: .info)
///
/// // Use CocoaLumberjack as usual
/// DDLogInfo("User logged in")
/// DDLogError("Payment failed")
/// ```
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/).
/// - Warning: This logger requires Sentry SDK to be initialized before use.
public class SentryCocoaLumberjackLogger: DDAbstractLogger {
    
    /// Creates a new SentryCocoaLumberjackLogger instance.
    ///
    /// - Note: Make sure to initialize the Sentry SDK before creating this logger.
    ///   Use `DDLog.add(_:with:)` to configure log level filtering.
    public override init() {
        super.init()
    }
    
    /// Logs a message from CocoaLumberjack to Sentry.
    ///
    /// - Parameter logMessage: The log message from CocoaLumberjack containing the message, level, and metadata.
    public override func log(message logMessage: DDLogMessage) {
        guard SentrySDK.isEnabled else {
            return
        }
        
        var attributes: [String: Any] = [:]
        attributes["sentry.origin"] = "auto.logging.cocoalumberjack"
        
        attributes["cocoalumberjack.level"] = logFlagToString(logMessage.flag)
        attributes["code.file.path"] = logMessage.file
        attributes["code.function.name"] = logMessage.function ?? ""
        attributes["code.line.number"] = Int(logMessage.line)
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
            SentrySDK.logger.error(message, attributes: attributes)
        } else if flag.contains(.warning) {
            SentrySDK.logger.warn(message, attributes: attributes)
        } else if flag.contains(.info) {
            SentrySDK.logger.info(message, attributes: attributes)
        } else if flag.contains(.debug) {
            SentrySDK.logger.debug(message, attributes: attributes)
        } else if flag.contains(.verbose) {
            SentrySDK.logger.trace(message, attributes: attributes)
        } else {
            SentrySDK.logger.info(message, attributes: attributes)
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
