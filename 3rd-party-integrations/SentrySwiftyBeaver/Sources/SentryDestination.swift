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
/// import Sentry
/// import SwiftyBeaver
///
/// SentrySDK.start { options in
///     options.dsn = "YOUR_DSN"
///     options.logsEnabled = true
/// }
///
/// let log = SwiftyBeaver.self
/// let sentryDestination = SentryDestination()
/// log.addDestination(sentryDestination)
///
/// log.info("User logged in", context: ["userId": "12345", "sessionId": "abc"])
/// ```
public class SentryDestination: BaseDestination {
    
    /// Creates a new SentryDestination.
    ///
    /// Log level filtering should be configured on the destination itself using SwiftyBeaver's
    /// built-in `minLevel` property after initialization.
    public override init() {
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
        
        if let context = context {
            addContextToAttributes(&attributes, context: context)
        }
        
        logToSentry(level: level, message: msg, attributes: attributes)
        return nil
    }
    
    private func addContextToAttributes(_ attributes: inout [String: Any], context: Any) {
        if let contextDict = context as? [String: Any] {
            for (key, value) in contextDict {
                attributes["swiftybeaver.context.\(key)"] = value
            }
        } else {
            attributes["swiftybeaver.context"] = "\(context)"
        }
    }
    
    private func logToSentry(level: SwiftyBeaver.Level, message: String, attributes: [String: Any]) {
        switch level {
        case .verbose:
            SentrySDK.logger.trace(message, attributes: attributes)
        case .debug:
            SentrySDK.logger.debug(message, attributes: attributes)
        case .info:
            SentrySDK.logger.info(message, attributes: attributes)
        case .warning:
            SentrySDK.logger.warn(message, attributes: attributes)
        case .error:
            SentrySDK.logger.error(message, attributes: attributes)
        case .critical:
            SentrySDK.logger.fatal(message, attributes: attributes)
        case .fault:
            SentrySDK.logger.fatal(message, attributes: attributes)
        @unknown default:
            SentrySDK.logger.error(message, attributes: attributes)
        }
    }
}
