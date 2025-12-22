@_implementationOnly import _SentryPrivate

import Foundation

@objc @_spi(Private) public protocol SentryLoggerDelegate: AnyObject {
    @objc(captureLog:)
    func capture(log: SentryLog)
}

/// `SentryLogger` provides a structured logging interface that captures log entries
/// and sends them to Sentry. Supports multiple log levels (trace, debug, info, warn, 
/// error, fatal) and allows attaching arbitrary attributes for enhanced context.
///
/// ## Supported Attribute Types
/// - `String`, `Bool`, `Int`, `Double`
/// - `Float` (converted to `Double`)
/// - Other types (converted to string)
///
/// ## Usage
/// ```swift
/// let logger = SentrySDK.logger
/// logger.info("User logged in", attributes: ["userId": "12345"])
/// logger.error("Payment failed", attributes: ["errorCode": 500])
/// 
/// // Structured string interpolation with automatic type detection
/// logger.info("User \(userId) processed \(count) items with \(percentage)% success")
/// logger.debug("Processing \(itemCount) items, active: \(isActive)")
/// logger.warn("Retry attempt \(currentAttempt) of \(maxAttempts) failed")
/// ```
@objc
public final class SentryLogger: NSObject {
    private weak var delegate: SentryLoggerDelegate?
    private let dateProvider: SentryCurrentDateProvider
    
    @objc(initWithDelegate:dateProvider:)
    @_spi(Private) public init(delegate: SentryLoggerDelegate, dateProvider: SentryCurrentDateProvider) {
        self.delegate = delegate
        self.dateProvider = dateProvider
        super.init()
    }
    
    // NoOp Init
    init(dateProvider: SentryCurrentDateProvider) {
        self.dateProvider = dateProvider
        super.init()
    }
    
    // MARK: - Trace Level
    
    /// Logs a trace-level message with structured string interpolation and optional attributes.
    public func trace(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .trace, logMessage: message, attributes: attributes)
    }

    /// Logs a trace-level message with additional attributes.
    public func trace(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .trace, logMessage: message, attributes: attributes)
    }

    /// Logs a trace-level message.
    @objc(trace:)
    public func trace(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .trace, logMessage: message, attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    @objc(trace:attributes:)
    public func trace(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .trace, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Debug Level
    
    /// Logs a debug-level message with structured string interpolation and optional attributes.
    public func debug(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .debug, logMessage: message, attributes: attributes)
    }

    /// Logs a debug-level message with additional attributes.
    public func debug(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .debug, logMessage: message, attributes: attributes)
    }

    /// Logs a debug-level message.
    @objc(debug:)
    public func debug(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .debug, logMessage: message, attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    @objc(debug:attributes:)
    public func debug(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .debug, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Info Level
    
    /// Logs an info-level message with structured string interpolation and optional attributes.
    public func info(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .info, logMessage: message, attributes: attributes)
    }

    /// Logs an info-level message with additional attributes.
    public func info(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .info, logMessage: message, attributes: attributes)
    }

    /// Logs an info-level message.
    @objc(info:)
    public func info(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .info, logMessage: message, attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    @objc(info:attributes:)
    public func info(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .info, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Warn Level
    
    /// Logs a warning-level message with structured string interpolation and optional attributes.
    public func warn(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .warn, logMessage: message, attributes: attributes)
    }

    /// Logs a warning-level message with additional attributes.
    public func warn(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .warn, logMessage: message, attributes: attributes)
    }

    /// Logs a warning-level message.
    @objc(warn:)
    public func warn(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .warn, logMessage: message, attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    @objc(warn:attributes:)
    public func warn(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .warn, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Error Level
    
    /// Logs an error-level message with structured string interpolation and optional attributes.
    public func error(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .error, logMessage: message, attributes: attributes)
    }

    /// Logs an error-level message with additional attributes.
    public func error(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .error, logMessage: message, attributes: attributes)
    }

    /// Logs an error-level message.
    @objc(error:)
    public func error(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .error, logMessage: message, attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    @objc(error:attributes:)
    public func error(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .error, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Fatal Level
    
    /// Logs a fatal-level message with structured string interpolation and optional attributes.
    public func fatal(_ message: SentryLogMessage, attributes: [String: SentryAttributeValuable] = [:]) {
        captureLog(level: .fatal, logMessage: message, attributes: attributes)
    }

    /// Logs a fatal-level message with additional attributes.
    public func fatal(_ body: String, attributes: [String: SentryAttributeValuable]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .fatal, logMessage: message, attributes: attributes)
    }

    /// Logs a fatal-level message.
    @objc(fatal:)
    public func fatal(_ body: String) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .fatal, logMessage: message, attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    @objc(fatal:attributes:)
    public func fatal(_ body: String, attributes: [String: Any]) {
        let message = SentryLogMessage(stringLiteral: body)
        captureLog(level: .fatal, logMessage: message, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(
        level: SentryLog.Level,
        logMessage: SentryLogMessage,
        attributes: [String: Any]
    ) {
        guard let delegate else {
            return
        }
        // Convert provided attributes to SentryLog.Attribute format
        var logAttributes = attributes.mapValues { value in
            if let attributableValue = value as? SentryAttributeValuable {
                return SentryLog.Attribute(value: attributableValue.asAttributeValue)
            }
            return SentryLog.Attribute(value: value)
        }

        // Add template string if there are interpolations
        if !logMessage.attributes.isEmpty {
            logAttributes["sentry.message.template"] = .init(string: logMessage.template)
        }
        
        // Add attributes from the SentryLogMessage
        for (index, attribute) in logMessage.attributes.enumerated() {
            logAttributes["sentry.message.parameter.\(index)"] = attribute
        }

        let log = SentryLog(
            timestamp: dateProvider.date(),
            traceId: SentryId.empty,
            level: level,
            body: logMessage.message,
            attributes: logAttributes
        )
        delegate.capture(log: log)
    }
}
