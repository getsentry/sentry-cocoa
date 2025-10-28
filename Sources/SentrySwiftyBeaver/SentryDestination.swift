import Sentry
import SwiftyBeaver

/// A SwiftyBeaver destination that forwards log entries to Sentry's structured logging system.
///
/// `SentryDestination` extends SwiftyBeaver's `BaseDestination`, allowing you to integrate
/// Sentry's structured logging capabilities with SwiftyBeaver. This enables you to capture
/// application logs from SwiftyBeaver and send them to Sentry for analysis and monitoring.
///
/// ## Level Mapping
/// SwiftyBeaver levels are mapped to Sentry log levels:
/// - `.verbose` → `.trace`
/// - `.debug` → `.debug`
/// - `.info` → `.info`
/// - `.warning` → `.warn`
/// - `.error` → `.error`
/// - `.critical` → `.fatal`
/// - `.fault` → `.fatal`
///
/// ## Context Handling
/// When `context` is provided as a `[String: Any]` dictionary, each key-value pair is added
/// as an individual Sentry log attribute with the prefix `swiftybeaver.context.{key}`. For non-dictionary
/// contexts, the entire context is converted to a string attribute `swiftybeaver.context`.
///
/// ## Usage
/// ```swift
/// import SwiftyBeaver
/// import Sentry
///
/// // Initialize Sentry SDK
/// SentrySDK.start { options in
///     options.dsn = "YOUR_DSN"
/// }
///
/// // Configure SwiftyBeaver with Sentry destination
/// let log = SwiftyBeaver.self
/// let sentryDestination = SentryDestination()
/// log.addDestination(sentryDestination)
///
/// // Use the logger with dictionary context (preferred)
/// // This will create attributes: swiftybeaver.context.userId, swiftybeaver.context.sessionId
/// log.info("User logged in", context: ["userId": "12345", "sessionId": "abc"])
/// 
/// // This will create attributes: swiftybeaver.context.errorCode, swiftybeaver.context.amount
/// log.error("Payment failed", context: ["errorCode": 500, "amount": 99.99])
/// ```
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/).
/// - Warning: This destination requires Sentry SDK to be initialized before use.
public class SentryDestination: BaseDestination {
    
    private let sentryLogger: SentryLogger
    
    /// Creates a new SentryDestination.
    ///
    /// Log level filtering should be configured on the destination itself using SwiftyBeaver's
    /// built-in `minLevel` property after initialization.
    public override init() {
        self.sentryLogger = SentrySDK.logger
        super.init()
    }
    
    init(sentryLogger: SentryLogger) {
        self.sentryLogger = sentryLogger
        super.init()
    }
    
    /// Sends a log message to Sentry's structured logging system.
    ///
    /// - Parameters:
    ///   - level: The SwiftyBeaver log level
    ///   - msg: The log message
    ///   - thread: The thread identifier
    ///   - file: The source file name
    ///   - function: The function name
    ///   - line: The line number
    ///   - context: Additional context information
    /// - Returns: Always returns `nil` as per SwiftyBeaver convention
    public override func send(
        _ level: SwiftyBeaver.Level,
        msg: String,
        thread: String,
        file: String,
        function: String,
        line: Int,
        context: Any? = nil
    ) -> String? {
        var attributes: [String: Any] = [:]
        attributes["sentry.origin"] = "auto.logging.swiftybeaver"
        attributes["swiftybeaver.level"] = "\(level.rawValue)"
        attributes["swiftybeaver.thread"] = thread
        attributes["swiftybeaver.file"] = file
        attributes["swiftybeaver.function"] = function
        attributes["swiftybeaver.line"] = "\(line)"
        
        // Include context if provided
        if let context = context {
            addContextToAttributes(&attributes, context: context)
        }
        
        logToSentry(level: level, message: msg, attributes: attributes)
        return nil
    }
    
    private func addContextToAttributes(_ attributes: inout [String: Any], context: Any) {
        // If context is a dictionary, iterate and add individual attributes
        if let contextDict = context as? [String: Any] {
            for (key, value) in contextDict {
                attributes["swiftybeaver.context.\(key)"] = value
            }
        } else {
            // For non-dictionary context, convert to string
            attributes["swiftybeaver.context"] = "\(context)"
        }
    }
    
    private func logToSentry(level: SwiftyBeaver.Level, message: String, attributes: [String: Any]) {
        switch level {
        case .verbose:
            sentryLogger.trace(message, attributes: attributes)
        case .debug:
            sentryLogger.debug(message, attributes: attributes)
        case .info:
            sentryLogger.info(message, attributes: attributes)
        case .warning:
            sentryLogger.warn(message, attributes: attributes)
        case .error:
            sentryLogger.error(message, attributes: attributes)
        case .critical:
            sentryLogger.fatal(message, attributes: attributes)
        case .fault:
            sentryLogger.fatal(message, attributes: attributes)
        @unknown default:
            sentryLogger.error(message, attributes: attributes)
        }
    }
}
