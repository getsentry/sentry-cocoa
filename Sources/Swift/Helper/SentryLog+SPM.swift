@_implementationOnly import _SentryPrivate
import Foundation

// Swift extensions to provide properly typed log-related APIs for SPM builds.
// In SPM builds, SentryLog is only forward declared in the Objective-C headers,
// which causes Swift-to-Objective-C bridging issues. These extensions work around
// that limitation by providing Swift-native methods and properties that use dynamic
// dispatch internally.

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

#endif // SWIFT_PACKAGE
