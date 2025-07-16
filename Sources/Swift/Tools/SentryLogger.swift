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
/// logger.info(message: "Adding item %@ for user %@", params: [itemId, userId], attributes: ["extra": "123"])
/// logger.debug(message: "Processing %d items with %.2f%% completion", params: [count, percentage])
/// logger.warn(message: "Retry attempt %d of %d failed", params: [currentAttempt, maxAttempts])
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
        captureLog(level: .trace, body: body, params: [], attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, params: [], attributes: attributes)
    }
    
    /// Logs a trace-level message with string templating.
    public func trace(_ body: String, params: [CVarArg]) {
        captureLog(level: .trace, body: body, params: params, attributes: [:])
    }
    
    /// Logs a trace-level message with string templating and additional attributes.
    public func trace(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .trace, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Debug Level
    
    /// Logs a debug-level message.
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, params: [], attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, params: [], attributes: attributes)
    }
    
    /// Logs a debug-level message with string templating.
    public func debug(_ body: String, params: [CVarArg]) {
        captureLog(level: .debug, body: body, params: params, attributes: [:])
    }
    
    /// Logs a debug-level message with string templating and additional attributes.
    public func debug(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .debug, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Info Level
    
    /// Logs an info-level message.
    public func info(_ body: String) {
        captureLog(level: .info, body: body, params: [], attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, params: [], attributes: attributes)
    }
    
    /// Logs an info-level message with string templating.
    public func info(_ body: String, params: [CVarArg]) {
        captureLog(level: .info, body: body, params: params, attributes: [:])
    }
    
    /// Logs an info-level message with string templating and additional attributes.
    public func info(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .info, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Warn Level
    
    /// Logs a warning-level message.
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, params: [], attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, params: [], attributes: attributes)
    }
    
    /// Logs a warning-level message with string templating.
    public func warn(_ body: String, params: [CVarArg]) {
        captureLog(level: .warn, body: body, params: params, attributes: [:])
    }
    
    /// Logs a warning-level message with string templating and additional attributes.
    public func warn(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .warn, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Error Level
    
    /// Logs an error-level message.
    public func error(_ body: String) {
        captureLog(level: .error, body: body, params: [], attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, params: [], attributes: attributes)
    }
    
    /// Logs an error-level message with string templating.
    public func error(_ body: String, params: [CVarArg]) {
        captureLog(level: .error, body: body, params: params, attributes: [:])
    }
    
    /// Logs an error-level message with string templating and additional attributes.
    public func error(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .error, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Fatal Level
    
    /// Logs a fatal-level message.
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, params: [], attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, params: [], attributes: attributes)
    }
    
    /// Logs a fatal-level message with string templating.
    public func fatal(_ body: String, params: [CVarArg]) {
        captureLog(level: .fatal, body: body, params: params, attributes: [:])
    }
    
    /// Logs a fatal-level message with string templating and additional attributes.
    public func fatal(message: String, params: [CVarArg], attributes: [String: Any]) {
        captureLog(level: .fatal, body: message, params: params, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, params: [CVarArg], attributes: [String: Any]) {
        guard let batcher else {
            return
        }
        var logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        if !params.isEmpty {
            logAttributes["sentry.message.template"] = .string(body)
        }
        for (index, param) in params.enumerated() {
            logAttributes["sentry.message.parameter.\(index)"] = SentryLog.Attribute(value: param)
        }
        
        let log = SentryLog(
            timestamp: dateProvider.date(),
            level: level,
            body: formatMessage(message: body, params: params),
            attributes: logAttributes
        )
        batcher.add(log)
    }
    
    private func formatMessage(message: String, params: [CVarArg]) -> String {
        guard !params.isEmpty else {
            return message
        }
        
        // Use NSString formatting with getVaList for direct CVaListPointer creation
        return NSString(format: message, arguments: getVaList(params)) as String
    }
}
