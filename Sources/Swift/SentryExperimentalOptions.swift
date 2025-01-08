@objcMembers
public class SentryExperimentalOptions: NSObject {
    /**
     * Enables swizzling of`NSFileManager` to automatically track file operations.
     */
    public var enableFileManagerSwizzling = false

    func validateOptions(_ options: [String: Any]?) {
    }
}
