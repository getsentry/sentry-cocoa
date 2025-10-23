@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private) public protocol SentryLogBatcherDelegate: AnyObject {
    @objc(captureLogsData:with:)
    func capture(logsData: NSData, count: NSNumber)
}

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let options: Options
    private let flushTimeout: TimeInterval
    private let maxBufferSizeBytes: Int
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    // All mutable state is accessed from the same serial dispatch queue.
    
    // Every logs data is added sepratley. They are flushed together in an envelope.
    private var encodedLogs: [Data] = []
    private var encodedLogsSize: Int = 0
    private var timerWorkItem: DispatchWorkItem?

    public weak var delegate: SentryLogBatcherDelegate?
    
    /// Convenience initializer with default flush timeout and buffer size.
    /// - Parameters:
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    @_spi(Private) public convenience init(options: Options, dispatchQueue: SentryDispatchQueueWrapper) {
        self.init(
            options: options,
            flushTimeout: 5,
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB
            dispatchQueue: dispatchQueue
        )
    }

    /// Initializes a new SentryLogBatcher.
    /// - Parameters:
    ///   - flushTimeout: The timeout interval after which buffered logs will be flushed
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    @_spi(Private) public init(
        options: Options,
        flushTimeout: TimeInterval,
        maxBufferSizeBytes: Int,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.options = options
        self.flushTimeout = flushTimeout
        self.maxBufferSizeBytes = maxBufferSizeBytes
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    @_spi(Private) @objc public func addLog(_ log: SentryLog, scope: Scope) {
        guard options.enableLogs else {
            return
        }

        addDefaultAttributes(to: &log.attributes, scope: scope)
        addOSAttributes(to: &log.attributes, scope: scope)
        addDeviceAttributes(to: &log.attributes, scope: scope)
        addUserAttributes(to: &log.attributes, scope: scope)

        let propagationContextTraceIdString = scope.propagationContextTraceIdString
        log.traceId = SentryId(uuidString: propagationContextTraceIdString)

        var processedLog: SentryLog? = log
        if let beforeSendLog = options.beforeSendLog {
            processedLog = beforeSendLog(log)
        }
        
        if let processedLog {
            SentrySDKLog.log(
                message: "[SentryLogger] \(processedLog.body)",
                andLevel: processedLog.level.toSentryLevel()
            )
            dispatchQueue.dispatchAsync { [weak self] in
                self?.encodeAndBuffer(log: processedLog)
            }
        }
    }
    
    // Captures batched logs sync and returns the duration.
    @discardableResult
    @_spi(Private) @objc public func captureLogs() -> TimeInterval {
        let startTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureLogs()
        }
        let endTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    // Helper

    private func addDefaultAttributes(to attributes: inout [String: SentryLog.Attribute], scope: Scope) {
        attributes["sentry.sdk.name"] = .init(string: SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .init(string: SentryMeta.versionString)
        attributes["sentry.environment"] = .init(string: options.environment)
        if let releaseName = options.releaseName {
            attributes["sentry.release"] = .init(string: releaseName)
        }
        if let span = scope.span {
            attributes["sentry.trace.parent_span_id"] = .init(string: span.spanId.sentrySpanIdString)
        }
    }

    private func addOSAttributes(to attributes: inout [String: SentryLog.Attribute], scope: Scope) {
        guard let osContext = scope.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .init(string: osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .init(string: osVersion)
        }
    }
    
    private func addDeviceAttributes(to attributes: inout [String: SentryLog.Attribute], scope: Scope) {
        guard let deviceContext = scope.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
            return
        }
        // For Apple devices, brand is always "Apple"
        attributes["device.brand"] = .init(string: "Apple")
        
        if let deviceModel = deviceContext["model"] as? String {
            attributes["device.model"] = .init(string: deviceModel)
        }
        if let deviceFamily = deviceContext["family"] as? String {
            attributes["device.family"] = .init(string: deviceFamily)
        }
    }

    private func addUserAttributes(to attributes: inout [String: SentryLog.Attribute], scope: Scope) {
        guard let user = scope.userObject else {
            return
        }
        if let userId = user.userId {
            attributes["user.id"] = .init(string: userId)
        }
        if let userName = user.name {
            attributes["user.name"] = .init(string: userName)
        }
        if let userEmail = user.email {
            attributes["user.email"] = .init(string: userEmail)
        }
    }

    // Only ever call this from the serial dispatch queue.
    private func encodeAndBuffer(log: SentryLog) {
        do {
            let encodedLog = try encodeToJSONData(data: log)
            
            let encodedLogsWereEmpty = encodedLogs.isEmpty
            
            encodedLogs.append(encodedLog)
            encodedLogsSize += encodedLog.count
            
            if encodedLogsSize >= maxBufferSizeBytes {
                performCaptureLogs()
            } else if encodedLogsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode log: \(error)")
        }
    }
    
    // Only ever call this from the serial dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("SentryLogBatcher: Timer fired, calling performFlush().")
            self?.performCaptureLogs()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: flushTimeout, workItem: timerWorkItem)
    }

    // Only ever call this from the serial dispatch queue.
    private func performCaptureLogs() {
        // Reset logs on function exit
        defer {
            encodedLogs.removeAll()
            encodedLogsSize = 0
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil
        
        guard encodedLogs.count > 0 else {
            SentrySDKLog.debug("SentryLogBatcher: No logs to flush.")
            return
        }

        // Create the payload.
        
        var payloadData = Data()
        payloadData.append(Data("{\"items\":[".utf8))
        let separator = Data(",".utf8)
        for (index, encodedLog) in encodedLogs.enumerated() {
            if index > 0 {
                payloadData.append(separator)
            }
            payloadData.append(encodedLog)
        }
        payloadData.append(Data("]}".utf8))
        
        // Send the payload.
        delegate?.capture(logsData: payloadData as NSData, count: NSNumber(value: encodedLogs.count))
    }
}

#if SWIFT_PACKAGE
/**
 * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
 * drop the log.
 */
public typealias SentryBeforeSendLogCallback = (SentryLog) -> SentryLog?

// Makes the `beforeSendLog` property visible as the Swift type `SentryBeforeSendLogCallback`.
// This works around `SentryLog` being only forward declared in the objc header, resulting in
// compile time issues with SPM builds.
@objc
public extension Options {
    /**
     * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
     * drop the log.
     */
    @objc
    var beforeSendLog: SentryBeforeSendLogCallback? {
        // Note: This property provides SentryLog type safety for SPM builds where the native Objective-C
        // property cannot be used due to Swift-to-Objective-C bridging limitations.
        get { return value(forKey: "beforeSendLogDynamic") as? SentryBeforeSendLogCallback }
        set { setValue(newValue, forKey: "beforeSendLogDynamic") }
    }
}
#endif // SWIFT_PACKAGE
