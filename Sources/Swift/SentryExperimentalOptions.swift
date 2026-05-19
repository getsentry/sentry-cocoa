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
     * Enables network detail capture for Session Replay.
     *
     * When enabled, the SDK can capture request and response headers and bodies for network
     * requests during session replay. You must also configure
     * `options.sessionReplay.networkDetailAllowUrls` with URL patterns to specify which
     * requests should be captured.
     */
    public var enableReplayNetworkDetailsCapturing = false

    // swiftlint:disable:next missing_docs
    @_spi(Private) public func validateOptions(_ options: [String: Any]?) {
    }
}
