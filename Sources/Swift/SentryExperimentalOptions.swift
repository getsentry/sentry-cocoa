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

    /// When enabled, the SDK uses a more efficient mechanism for detecting watchdog terminations.
    public var enableWatchdogTerminationsV2 = false

    /**
     * When enabled, the SDK sends a standalone app start transaction instead of attaching app
     * start data to the first UIViewController transaction.
     */
    public var enableStandaloneAppStartTracing = false

    /**
     * When enabled, the SDK defers `UIViewController` performance swizzling to the first time each
     * view controller is instantiated, instead of eagerly discovering and swizzling all
     * `UIViewController` subclasses at SDK start.
     *
     * The eager approach realizes classes to inspect them, which crashes on OS versions below an
     * `@available`-gated view controller subclass's gate when that subclass references a
     * newer-framework type (see https://github.com/getsentry/sentry-cocoa/issues/8548). Deferring to
     * first instantiation avoids this: a class that can't exist on the current OS is never
     * instantiated, so the SDK never realizes it.
     *
     * - Experiment: This is an experimental feature and is therefore disabled by default. We'll
     *   enable it by default in a future major release.
     */
    public var enableUIViewControllerInitSwizzling = false
}
