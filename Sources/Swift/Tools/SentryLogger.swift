import Foundation

/// **EXPERIMENTAL** - A structured logging API for Sentry.
///
/// `SentryLogger` provides a structured logging interface that captures log entries
/// and sends them to Sentry. Supports multiple log levels (trace, debug, info, warn, 
/// error, fatal) and allows attaching arbitrary attributes for enhanced context.
///
/// ## Supported Attribute Types
/// - `String`, `Bool`, `Int`, `Double`
/// - `Float` (converted to `Double`)
/// - Other types (converted to string)
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/product/explore/logs/).
/// - Warning: This API is experimental and subject to change without notice.
///
/// ## Usage
/// ```swift
/// let logger = SentrySDK.logger
/// logger.info("User logged in", attributes: ["userId": "12345"])
/// logger.error("Payment failed", attributes: ["errorCode": 500])
/// 
/// // String templating with various format specifiers
/// logger.info("Adding item %@ for user %@", arguments: [itemId, userId], attributes: ["extra": "123"])
/// logger.debug("Processing %d items with %.2f%% completion", arguments: [count, percentage])
/// logger.warn("Retry attempt %d of %d failed", arguments: [currentAttempt, maxAttempts])
/// ```
@objc
@objcMembers
public final class SentryLogger: NSObject {
    private let hub: SentryHub
    private let dateProvider: SentryCurrentDateProvider
    // Nil in the case where the Hub's client is nil or logs are disabled through options.
    private let batcher: SentryLogBatcher?
    
    @_spi(Private) public init(hub: SentryHub, dateProvider: SentryCurrentDateProvider, batcher: SentryLogBatcher?) {
        self.hub = hub
        self.dateProvider = dateProvider
        self.batcher = batcher
        super.init()
    }
    
    // MARK: - Trace Level
    
    /// Logs a trace-level message.
    public func trace(_ body: String) {
        captureLog(level: .trace, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs a trace-level message with string templating.
    public func trace(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .trace, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs a trace-level message with string templating and additional attributes.
    public func trace(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .trace, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Debug Level
    
    /// Logs a debug-level message.
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs a debug-level message with string templating.
    public func debug(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .debug, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs a debug-level message with string templating and additional attributes.
    public func debug(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .debug, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Info Level
    
    /// Logs an info-level message.
    public func info(_ body: String) {
        captureLog(level: .info, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs an info-level message with string templating.
    public func info(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .info, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs an info-level message with string templating and additional attributes.
    public func info(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .info, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Warn Level
    
    /// Logs a warning-level message.
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs a warning-level message with string templating.
    public func warn(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .warn, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs a warning-level message with string templating and additional attributes.
    public func warn(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .warn, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Error Level
    
    /// Logs an error-level message.
    public func error(_ body: String) {
        captureLog(level: .error, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs an error-level message with string templating.
    public func error(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .error, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs an error-level message with string templating and additional attributes.
    public func error(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .error, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Fatal Level
    
    /// Logs a fatal-level message.
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, arguments: [], attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, arguments: [], attributes: attributes)
    }
    
    /// Logs a fatal-level message with string templating.
    public func fatal(_ body: String, arguments: [CVarArg]) {
        captureLog(level: .fatal, body: body, arguments: arguments, attributes: [:])
    }
    
    /// Logs a fatal-level message with string templating and additional attributes.
    public func fatal(_ body: String, arguments: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, arguments: arguments, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, arguments: [CVarArg], attributes: [String: Any]) {
        guard let batcher else {
            return
        }
        var logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        if !arguments.isEmpty {
            logAttributes["sentry.message.template"] = .string(body)
        }
        for (index, argument) in arguments.enumerated() {
            logAttributes["sentry.message.parameter.\(index)"] = SentryLog.Attribute(value: argument)
        }
        
        let log = SentryLog(
            timestamp: dateProvider.date(),
            level: level,
            body: format(body: body, arguments: arguments),
            attributes: logAttributes
        )
        batcher.add(log)
    }
    
    private func format(body: String, arguments: [CVarArg]) -> String {
        guard !arguments.isEmpty else {
            return body
        }
        return NSString(format: body, arguments: getVaList(arguments)) as String
    }
}
