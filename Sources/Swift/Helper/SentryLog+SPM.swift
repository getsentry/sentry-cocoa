@_implementationOnly import _SentryPrivate
import Foundation

// Swift extensions to provide properly typed log-related APIs for SPM builds.
// In SPM builds, SentryLog is only forward declared in the Objective-C headers,
// causing Swift-to-Objective-C bridging issues. These extensions work around that
// by providing Swift-native methods and properties that use dynamic dispatch internally.

@objc
protocol CaptureLogSelectors {
    func captureLog(_ log: SentryLog)
    func captureLog(_ log: SentryLog, withScope: Scope)
}

/// Helper class to handle dynamic dispatch for log capture.
/// This is used in SPM builds to work around Swift-to-Objective-C bridging issues.
@objc
class CaptureLogDispatcher: NSObject {
    
    /// Captures a log using dynamic dispatch on the target object
    /// - Parameters:
    ///   - log: The log to capture
    ///   - target: The object that should handle the log capture (typically SentryHub)
    /// - Returns: true if the log was captured, false if the selector was not available
    @discardableResult
    static func captureLog(_ log: SentryLog, on target: NSObject) -> Bool {
        let selector = #selector(CaptureLogSelectors.captureLog(_:))
        guard target.responds(to: selector) else {
            SentrySDKLog.error("Target \(type(of: target)) does not respond to captureLog(_:). The log will not be captured.")
            return false
        }
        target.perform(selector, with: log)
        return true
    }
    
    /// Captures a log with a scope using dynamic dispatch on the target object
    /// - Parameters:
    ///   - log: The log to capture
    ///   - scope: The scope containing event metadata
    ///   - target: The object that should handle the log capture (typically SentryHub or SentryClient)
    /// - Returns: true if the log was captured, false if the selector was not available
    @discardableResult
    static func captureLog(_ log: SentryLog, withScope scope: Scope, on target: NSObject) -> Bool {
        let selector = #selector(CaptureLogSelectors.captureLog(_:withScope:))
        guard target.responds(to: selector) else {
            SentrySDKLog.error("Target \(type(of: target)) does not respond to captureLog(_:withScope:). The log will not be captured.")
            return false
        }
        target.perform(selector, with: log, with: scope)
        return true
    }
}

#if SWIFT_PACKAGE

/**
 * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
 * drop the log.
 */
public typealias SentryBeforeSendLogCallback = (SentryLog) -> SentryLog?

@objc
public extension Options {
    /**
     * Use this callback to drop or modify a log before the SDK sends it to Sentry. Return `nil` to
     * drop the log.
     */
    @objc
    var beforeSendLog: SentryBeforeSendLogCallback? {
        get { return value(forKey: "beforeSendLogDynamic") as? SentryBeforeSendLogCallback }
        set { setValue(newValue, forKey: "beforeSendLogDynamic") }
    }
}

@objc
public extension SentryHub {
    /// Captures a log entry and sends it to Sentry.
    /// - Parameter log: The log entry to send to Sentry.
    ///
    /// This method is provided for SPM builds where the Objective-C `captureLog:` method
    /// may not be properly bridged due to `SentryLog` being defined in Swift.
    func capture(log: SentryLog) {
        CaptureLogDispatcher.captureLog(log, on: self)
    }
    
    /// Captures a log entry and sends it to Sentry with a specific scope.
    /// - Parameters:
    ///   - log: The log entry to send to Sentry.
    ///   - scope: The scope containing event metadata.
    ///
    /// This method is provided for SPM builds where the Objective-C `captureLog:withScope:` method
    /// may not be properly bridged due to `SentryLog` being defined in Swift.
    func capture(log: SentryLog, scope: Scope) {
        CaptureLogDispatcher.captureLog(log, withScope: scope, on: self)
    }
}

/// Extension to provide log capture methods for SPM builds.
@objc
public extension SentryClient {
    /// Captures a log entry and sends it to Sentry.
    /// - Parameters:
    ///   - log: The log entry to send to Sentry.
    ///   - scope: The scope containing event metadata.
    func captureLog(_ log: SentryLog, withScope scope: Scope) {
        CaptureLogDispatcher.captureLog(log, withScope: scope, on: self)
    }
}

#endif // SWIFT_PACKAGE
