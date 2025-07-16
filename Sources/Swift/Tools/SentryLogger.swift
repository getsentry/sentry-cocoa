@_implementationOnly import _SentryPrivate

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
    
    /// Logs a trace-level message.
    public func trace(_ body: String) {
        captureLog(level: .trace, body: body, attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, attributes: attributes)
    }
    
    /// Logs a debug-level message.
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, attributes: attributes)
    }
    
    /// Logs an info-level message.
    public func info(_ body: String) {
        captureLog(level: .info, body: body, attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, attributes: attributes)
    }
    
    /// Logs a warning-level message.
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, attributes: attributes)
    }
    
    /// Logs an error-level message.
    public func error(_ body: String) {
        captureLog(level: .error, body: body, attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, attributes: attributes)
    }
    
    /// Logs a fatal-level message.
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, attributes: [String: Any]) {
        guard let batcher else {
            return
        }
        
        var logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        addDefaultAttributes(to: &logAttributes)

        let propagationContextTraceIdString = hub.scope.propagationContextTraceIdString
        let propagationContextTraceId = SentryId(uuidString: propagationContextTraceIdString)

        batcher.add(
            SentryLog(
                timestamp: dateProvider.date(),
                traceId: propagationContextTraceId,
                level: level,
                body: body,
                attributes: logAttributes
            )
        )
    }

    private func addDefaultAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let batcher else {
            return
        }
        attributes["sentry.sdk.name"] = .string(SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .string(SentryMeta.versionString)
        attributes["sentry.environment"] = .string(batcher.options.environment)
        if let releaseName = batcher.options.releaseName {
            attributes["sentry.release"] = .string(releaseName)
        }
        if let span = hub.scope.span {
            attributes["sentry.trace.parent_span_id"] = .string(span.spanId.sentrySpanIdString)
        }
    }
}
