@objcMembers
public class SentryExperimentalOptions: NSObject {
    /**
     * Disables swizzling of`NSData` to automatically track file operations.
     */
    public var disableDataSwizzling = false

    /**
     * Enables swizzling of`NSFileManager` to automatically track file operations.
     */
    public var enableFileManagerSwizzling = false

    func validateOptions(_ options: [String: Any]?) {
    }
}
