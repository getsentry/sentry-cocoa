@objcMembers
public class SentryExperimentalOptions: NSObject {
    /**
     * Disables swizzling of`NSData` to automatically track file operations.
     *
     * - Note: Swizzling is enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     *         This option allows you to disable swizzling for `NSData` only, while keeping swizzling enabled for other classes.
     *         This is useful if you want to use manual tracing for file operations.
     */
    public var disableDataSwizzling = false

    /**
     * Enables swizzling of`NSFileManager` to automatically track file operations.
     *
     * - Requires: Swizzling must be enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     */
    public var enableFileManagerSwizzling = false

    func validateOptions(_ options: [String: Any]?) {
    }
}
