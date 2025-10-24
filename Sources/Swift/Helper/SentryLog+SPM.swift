@_implementationOnly import _SentryPrivate
import Foundation

// Swift extensions to provide properly typed log-related APIs for SPM builds.
// In SPM builds, SentryLog is only forward declared in the Objective-C headers,
// causing Swift-to-Objective-C bridging issues. These extensions work around that
// by providing Swift-native methods and properties that use dynamic dispatch internally.

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
@_spi(Private) public protocol HubSelectors {
    func captureLog(_ log: SentryLog)
    func captureLog(_ log: SentryLog, withScope: Scope)
}

@objc
public extension SentryHub {
    /// Captures a log entry and sends it to Sentry.
    /// - Parameter log: The log entry to send to Sentry.
    ///
    /// This method is provided for SPM builds where the Objective-C `captureLog:` method
    /// may not be properly bridged due to `SentryLog` being defined in Swift.
    func capture(log: SentryLog) {
        // Use dynamic dispatch to work around bridging limitations
        perform(#selector(HubSelectors.captureLog(_:)), with: log)
    }
    
    /// Captures a log entry and sends it to Sentry with a specific scope.
    /// - Parameters:
    ///   - log: The log entry to send to Sentry.
    ///   - scope: The scope containing event metadata.
    ///
    /// This method is provided for SPM builds where the Objective-C `captureLog:withScope:` method
    /// may not be properly bridged due to `SentryLog` being defined in Swift.
    func capture(log: SentryLog, scope: Scope) {
        // Use dynamic dispatch to work around bridging limitations
        perform(#selector(HubSelectors.captureLog(_:withScope:)), with: log, with: scope)
    }
}

@objc
@_spi(Private) public protocol ClientSelectors {
    func captureLog(_ log: SentryLog, withScope: Scope)
}

/// Extension to provide log capture methods for SPM builds.
@objc
public extension SentryClient {
    /// Captures a log entry and sends it to Sentry.
    /// - Parameters:
    ///   - log: The log entry to send to Sentry.
    ///   - scope: The scope containing event metadata.
    func captureLog(_ log: SentryLog, withScope scope: Scope) {
        // Use dynamic dispatch to work around bridging limitations
        perform(#selector(ClientSelectors.captureLog(_:withScope:)), with: log, with: scope)
    }
}

#endif // SWIFT_PACKAGE
