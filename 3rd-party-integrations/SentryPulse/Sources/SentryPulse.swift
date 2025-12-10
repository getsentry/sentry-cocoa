import Combine
import Pulse
import Sentry

/// Automatically forwards Pulse log messages to Sentry's structured logging system.
///
/// `SentryPulse` observes Pulse's `LoggerStore.events` publisher and automatically
/// forwards all `.messageCreated` events to Sentry. This provides seamless integration between
/// Pulse and Sentry without requiring any changes to existing logging code.
///
/// ## How It Works
/// - Subscribes to Pulse's `LoggerStore.events` publisher
/// - Listens for `.messageCreated` events
/// - Automatically forwards each log message to Sentry with appropriate level mapping
/// - Preserves all metadata and source information
///
/// ## Level Mapping
/// Pulse log levels are mapped to Sentry log levels:
/// - `.trace` → `.trace`
/// - `.debug` → `.debug`
/// - `.info` → `.info`
/// - `.notice` → `.info` (notice maps to info as SentryLog doesn't have notice)
/// - `.warning` → `.warn`
/// - `.error` → `.error`
/// - `.critical` → `.fatal`
///
/// ## Usage
///
/// ```swift
/// import Pulse
/// import Sentry
/// import SentryPulse
///
/// SentrySDK.start { options in
///     options.dsn = "YOUR_DSN"
/// }
/// 
/// // Setup Pulse...
/// 
/// SentryPulse.start()
/// ```
///
/// ## Lifecycle Management
/// - Call `SentryPulse.start()` once during app initialization to enable integration
/// - Call `SentryPulse.stop()` to disable log forwarding
/// - Integration persists for the lifetime of the app (unless explicitly stopped)
///
/// - Note: Sentry Logs is currently in Beta. See the [Sentry Logs Documentation](https://docs.sentry.io/platforms/apple/logs/).
public final class SentryPulse {
    
    private nonisolated(unsafe) static var shared: SentryPulse?
    private static let lock = NSLock()
    
    private var cancellable: AnyCancellable?
    private let sentryLogger: SentryLogger
    
    /// Starts forwarding Pulse logs to Sentry.
    ///
    /// Call this method once during app initialization, after initializing the Sentry SDK.
    /// The integration will remain active for the lifetime of the app (or until `stop()` is called).
    ///
    /// ```swift
    /// import Pulse
    /// import Sentry
    /// import SentryPulse
    /// 
    /// SentrySDK.start { options in
    ///     options.dsn = "YOUR_DSN"
    /// }
    ///
    /// // Setup Pulse...
    /// 
    /// SentryPulse.start()
    /// ```
    ///
    /// - Parameters:
    ///   - loggerStore: The Pulse `LoggerStore` to observe. Defaults to `.shared`.
    ///
    /// - Note: Calling this method multiple times has no effect. The integration is started only once.
    public static func start(loggerStore: LoggerStore = .shared) {
        startInternal(loggerStore: loggerStore, sentryLogger: SentrySDK.logger)
    }
    
    // Internal method for testing
    static func startInternal(loggerStore: LoggerStore, sentryLogger: SentryLogger) {
        lock.lock()
        defer { lock.unlock() }
        
        guard shared == nil else { return }
        shared = SentryPulse(loggerStore: loggerStore, sentryLogger: sentryLogger)
    }
    
    /// Stops forwarding Pulse logs to Sentry.
    ///
    /// After calling this method, Pulse logs will no longer be sent to Sentry.
    /// You can call `start()` again to re-enable the integration.
    public static func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        shared?.stop()
        shared = nil
    }
    
    // Internal initializer for testing
    init(loggerStore: LoggerStore, sentryLogger: SentryLogger) {
        self.sentryLogger = sentryLogger
        cancellable = loggerStore.events
            .sink { [weak self] event in
                guard let self = self else { return }
                
                if case .messageStored(let message) = event {
                    self.forwardMessageToSentry(message)
                }
            }
    }
    
    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Private Implementation
    
    private func forwardMessageToSentry(_ message: LoggerStore.Event.MessageCreated) {
        // Build attributes with Pulse-specific metadata
        var attributes: [String: Any] = [:]
        attributes["sentry.origin"] = "auto.logging.pulse"
        attributes["pulse.level"] = message.level.name
        attributes["pulse.label"] = message.label
        if !message.file.isEmpty {
            attributes["pulse.file"] = message.file
        }
        if !message.function.isEmpty {
            attributes["pulse.function"] = message.function
        }
        attributes["pulse.line"] = message.line
        
        // Add metadata from Pulse message (already converted to [String: String])
        if let metadata = message.metadata {
            for (key, value) in metadata {
                attributes["pulse.\(key)"] = value
            }
        }
        
        // Forward to Sentry logger with appropriate level
        logToSentry(message.level, message: message.message, attributes: attributes)
    }
    
    private func logToSentry(_ level: LoggerStore.Level, message: String, attributes: [String: Any]) {
        switch level {
        case .trace:
            sentryLogger.trace(message, attributes: attributes)
        case .debug:
            sentryLogger.debug(message, attributes: attributes)
        case .info:
            sentryLogger.info(message, attributes: attributes)
        case .notice:
            // Map notice to info as SentryLog doesn't have notice
            sentryLogger.info(message, attributes: attributes)
        case .warning:
            sentryLogger.warn(message, attributes: attributes)
        case .error:
            sentryLogger.error(message, attributes: attributes)
        case .critical:
            sentryLogger.fatal(message, attributes: attributes)
        }
    }
}
