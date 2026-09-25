import Foundation

/// Options for experimental features that are subject to change or may be removed in future versions.
@objcMembers
public final class SentryExperimentalOptions: NSObject {
    @nonobjc var unhandledCPPExceptionsV2Enabled = false

    /// Use ``Options/enableUnhandledCPPExceptionsV2`` instead.
    /// This alias will be removed in the next minor release.
    @available(*, deprecated, renamed: "Options.enableUnhandledCPPExceptionsV2")
    public var enableUnhandledCPPExceptionsV2: Bool {
        get { unhandledCPPExceptionsV2Enabled }
        set { unhandledCPPExceptionsV2Enabled = newValue }
    }

    /// Enables swizzling for automatic network instrumentation of the new URLSession HTTP loader.
    /// Requires `Options.enableSwizzling` and an enabled network tracking feature.
    /// Classic-loader instrumentation is unaffected by this option.
    ///
    /// Disabled by default while this experimental instrumentation is being tested.
    /// Configure this option before starting the SDK. Installed swizzles remain for the process
    /// lifetime, but bypass new-loader instrumentation if the SDK restarts with this option disabled.
    public var enableNewURLLoaderSwizzling = false

    #if !SDK_V10
    @nonobjc var enableWatchdogTerminationsV2Value = false

    /// When enabled, the SDK uses a more efficient mechanism for detecting watchdog terminations.
    /// - Deprecated: This option will be removed in v10, where the improved watchdog termination
    ///   tracking mechanism is enabled by default.
    public var enableWatchdogTerminationsV2: Bool {
        get {
            enableWatchdogTerminationsV2Value
        }
        @available(*, deprecated, message: "enableWatchdogTerminationsV2 is deprecated and will be removed in v10, where the improved watchdog termination tracking mechanism is enabled by default.")
        set {
            enableWatchdogTerminationsV2Value = newValue
        }
    }
    #endif

    /**
     * Reduces SDK start overhead by swizzling each `UIViewController` subclass lazily, the first
     * time an instance of it is created, instead of eagerly discovering and swizzling every
     * subclass when the SDK starts.
     *
     * By default, the SDK scans loaded binary images for all `UIViewController` subclasses at
     * start and swizzles them up front. This realizes every subclass to inspect it, so the cost
     * grows with the number of view controllers in the app - including ones it never uses - and it
     * realizes `@available`-gated subclasses that reference newer-framework types, which crashes on
     * OS versions below the gate.
     *
     * With this option, only classes the app actually instantiates are touched: a class that can't
     * exist on the current OS is never instantiated, so it's never realized or swizzled. This cuts
     * start-up work and avoids the gated-subclass crash while producing the same `ui.load`
     * auto-instrumentation transactions.
     *
     * See https://github.com/getsentry/sentry-cocoa/issues/8548.
     */
    public var enableUIViewControllerInitSwizzling = false
}
