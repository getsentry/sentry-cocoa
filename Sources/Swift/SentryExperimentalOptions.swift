@objcMembers
public class SentryExperimentalOptions: NSObject {
    /**
     * Enables swizzling of`NSData` to automatically track file operations.
     *
     * - Note: Swizzling is enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     *         This option allows you to disable swizzling for `NSData` only, while keeping swizzling enabled for other classes.
     *         This is useful if you want to use manual tracing for file operations.
     */
    public var enableDataSwizzling = true

    /**
     * Enables swizzling of`NSFileManager` to automatically track file operations.
     *
     * - Note: Swizzling is enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     *         This option allows you to disable swizzling for `NSFileManager` only, while keeping swizzling enabled for other classes.
     *         This is useful if you want to use manual tracing for file operations.
     * - Experiment: This is an experimental feature and is therefore disabled by default. We'll enable it by default in a future release.
     */
    public var enableFileManagerSwizzling = false

    /**
     * Enables the experimental view renderer used by the Session Replay integration.
     *
     * Rendering the view hierarchy is an expensive operation and can impact the performance of your app.
     * The experimental view renderer is optimized for performance, but might not render all views correctly.
     *
     * - Experiment: This is an experimental feature and is therefore disabled by default. In case you are noticing issues with the experimental
     *               view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa).
     */
    public var enableExperimentalViewRenderer = false

    func validateOptions(_ options: [String: Any]?) {
    }
}
