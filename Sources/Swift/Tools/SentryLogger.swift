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
/// 
/// // Structured string interpolation with automatic type detection
/// logger.info(formatted: "User \(userId) processed \(count) items with \(percentage)% success")
/// logger.debug(formatted: "Processing \(itemCount) items, active: \(isActive)")
/// logger.warn(formatted: "Retry attempt \(currentAttempt) of \(maxAttempts) failed")
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
        captureLog(level: .trace, body: body, attributes: [:])
    }
    
    /// Logs a trace-level message with additional attributes.
    public func trace(_ body: String, attributes: [String: Any]) {
        captureLog(level: .trace, body: body, attributes: attributes)
    }
    
    /// Logs a trace-level message with structured string interpolation.
    public func trace(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .trace, logString: body, attributes: attributes)
    }
    
    // MARK: - Debug Level
    
    /// Logs a debug-level message.
    public func debug(_ body: String) {
        captureLog(level: .debug, body: body, attributes: [:])
    }
    
    /// Logs a debug-level message with additional attributes.
    public func debug(_ body: String, attributes: [String: Any]) {
        captureLog(level: .debug, body: body, attributes: attributes)
    }
    
    /// Logs a debug-level message with structured string interpolation.
    public func debug(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .debug, logString: body, attributes: attributes)
    }
    
    // MARK: - Info Level
    
    /// Logs an info-level message.
    public func info(_ body: String) {
        captureLog(level: .info, body: body, attributes: [:])
    }
    
    /// Logs an info-level message with additional attributes.
    public func info(_ body: String, attributes: [String: Any]) {
        captureLog(level: .info, body: body, attributes: attributes)
    }
    
    /// Logs an info-level message with structured string interpolation.
    public func info(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .info, logString: body, attributes: attributes)
    }
    
    // MARK: - Warn Level
    
    /// Logs a warning-level message.
    public func warn(_ body: String) {
        captureLog(level: .warn, body: body, attributes: [:])
    }
    
    /// Logs a warning-level message with additional attributes.
    public func warn(_ body: String, attributes: [String: Any]) {
        captureLog(level: .warn, body: body, attributes: attributes)
    }
    
    /// Logs a warning-level message with structured string interpolation.
    public func warn(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .warn, logString: body, attributes: attributes)
    }
    
    // MARK: - Error Level
    
    /// Logs an error-level message.
    public func error(_ body: String) {
        captureLog(level: .error, body: body, attributes: [:])
    }
    
    /// Logs an error-level message with additional attributes.
    public func error(_ body: String, attributes: [String: Any]) {
        captureLog(level: .error, body: body, attributes: attributes)
    }
    
    /// Logs an error-level message with structured string interpolation.
    public func error(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .error, logString: body, attributes: attributes)
    }
    
    // MARK: - Fatal Level
    
    /// Logs a fatal-level message.
    public func fatal(_ body: String) {
        captureLog(level: .fatal, body: body, attributes: [:])
    }
    
    /// Logs a fatal-level message with additional attributes.
    public func fatal(_ body: String, attributes: [String: Any]) {
        captureLog(level: .fatal, body: body, attributes: attributes)
    }
    
    /// Logs a fatal-level message with structured string interpolation.
    public func fatal(formatted body: SentryLogMessage, attributes: [String: Any] = [:]) {
        captureLog(level: .fatal, logString: body, attributes: attributes)
    }
    
    // MARK: - Private
    
    private func captureLog(level: SentryLog.Level, body: String, attributes: [String: Any]) {
        let logString = SentryLogMessage(stringLiteral: body)
        captureLog(level: level, logString: logString, attributes: attributes)
    }

    private func captureLog(level: SentryLog.Level, logString: SentryLogMessage, attributes: [String: Any]) {
        guard let batcher else {
            return
        }
        
        // Convert provided attributes to SentryLog.Attribute format
        var logAttributes = attributes.mapValues { SentryLog.Attribute(value: $0) }
        
        // Add template string if there are interpolations
        if !logString.attributes.isEmpty {
            logAttributes["sentry.message.template"] = .string(logString.template)
        }
        
        // Add attributes from the SentryLogMessage
        for (index, attribute) in logString.attributes.enumerated() {
            logAttributes["sentry.message.parameter.\(index)"] = attribute
        }
        
        addDefaultAttributes(to: &logAttributes)
        addOSAttributes(to: &logAttributes)
        addDeviceAttributes(to: &logAttributes)
        addUserAttributes(to: &logAttributes)

        let propagationContextTraceIdString = hub.scope.propagationContextTraceIdString
        let propagationContextTraceId = SentryId(uuidString: propagationContextTraceIdString)

        batcher.add(
            SentryLog(
                timestamp: dateProvider.date(),
                traceId: propagationContextTraceId,
                level: level,
                body: logString.message,
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

    private func addOSAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let osContext = hub.scope.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .string(osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .string(osVersion)
        }
    }
    
    private func addDeviceAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let deviceContext = hub.scope.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
            return
        }
        // For Apple devices, brand is always "Apple"
        attributes["device.brand"] = .string("Apple")
        
        if let deviceModel = deviceContext["model"] as? String {
            attributes["device.model"] = .string(deviceModel)
        }
        if let deviceFamily = deviceContext["family"] as? String {
            attributes["device.family"] = .string(deviceFamily)
        }
    }

    private func addUserAttributes(to attributes: inout [String: SentryLog.Attribute]) {
        guard let user = hub.scope.userObject else {
            return
        }
        if let userId = user.userId {
            attributes["user.id"] = .string(userId)
        }
        if let userName = user.name {
            attributes["user.name"] = .string(userName)
        }
        if let userEmail = user.email {
            attributes["user.email"] = .string(userEmail)
        }
    }
}
