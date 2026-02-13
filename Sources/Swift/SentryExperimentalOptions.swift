import Foundation

/// Options for experimental features that are subject to change or may be removed in future versions.
@objcMembers
public final class SentryExperimentalOptions: NSObject {
    /**
     * A more reliable way to report unhandled C++ exceptions.
     *
     * This approach hooks into all instances of the `__cxa_throw` function, which provides a more comprehensive and consistent exception handling across an app’s runtime, regardless of the number of C++ modules or how they’re linked. It helps in obtaining accurate stack traces.
     *
     * - Note: The mechanism of hooking into `__cxa_throw` could cause issues with symbolication on iOS due to caching of symbol references.
     * - Experiment: This is an experimental feature and is therefore disabled by default. We'll enable it by default in a future major release.
     */
    public var enableUnhandledCPPExceptionsV2 = false

    /**
     * Forces enabling of session replay in unreliable environments.
     *
     * Due to internal changes with the release of Liquid Glass on iOS 26.0, the masking of text and images can not be reliably guaranteed.
     * Therefore the SDK uses a defensive programming approach to disable the session replay integration by default, unless the environment is detected as reliable.
     *
     * Indicators for reliable environments include:
     * - Running on an older version of iOS that doesn't have Liquid Glass (iOS 18 or earlier)
     * - UIDesignRequiresCompatibility is explicitly set to YES in Info.plist
     * - The app was built with Xcode < 26.0 (DTXcode < 2600)
     *
     * - Important: This flag allows to re-enable the session replay integration on iOS 26.0 and later, but please be aware that text and images may not be masked as expected.
     *
     * - Note: See [GitHub issues #6389](https://github.com/getsentry/sentry-cocoa/issues/6389) for more information.
     */
    public var enableSessionReplayInUnreliableEnvironment = false

    /// When enabled, the SDK sends metrics to Sentry. Metrics can be captured using the SentrySDK.metrics
    /// API, which allows you to send, view and query counters, gauges and measurements.
    /// @note Default value is @c true.
    @objc public var enableMetrics: Bool = true

    /// When enabled, the watchdog termination integration uses a run loop observer instead of the
    /// ANR tracker to detect main thread hangs. The run loop observer avoids creating a busy
    /// run loop, which can interfere with idle-time processing.
    /// @note Default value is @c false.
    /// @note This option is experimental and may be removed or changed in future versions.
    @objc public var enableWatchdogTerminationRunLoopHangTracker: Bool = false

    /// Use this callback to drop or modify a metric before the SDK sends it to Sentry. Return nil to
    /// drop the metric.
    public var beforeSendMetric: ((SentryMetric) -> SentryMetric?)?

    // swiftlint:disable:next missing_docs
    @_spi(Private) public func validateOptions(_ options: [String: Any]?) {
    }
}
