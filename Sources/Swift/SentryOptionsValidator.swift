@objcMembers
class SentryOptionsValidator: NSObject {
    @objc
    static func validate(options: Options) {
        SentryLog.debug("Validating Sentry SDK options")
        if !Self.isCacheDirectoryPathValid(path: options.cacheDirectoryPath) {
            SentryLog.fatal("The configured cache directory path looks invalid, the SDK might not be able to write reports to disk: \(options.cacheDirectoryPath)")
        }
    }

    @objc
    static func isCacheDirectoryPathValid(path: Any) -> Bool {
        guard let path = path as? String else {
            return false
        }
        let fileUrl = URL(fileURLWithPath: path)

        // The cache directory path is used as a base path in the SDK,
        // therefore actual paths can be even longer and it is necessary
        // to include some reserved space for appendix.
        //
        // The following length is assumed based on paths used in the SDK.
        let reservedInternalLength: Int32 = 256

        // PATH_MAX is defined in <sys/syslimits.h> and is the maximum length of a path in bytes.
        if path.count > PATH_MAX - reservedInternalLength {
            return false
        }

        // NAME_MAX is defined in <sys/syslimits.h> and is the maximum length of a filename / path component in bytes.
        if fileUrl.pathComponents.contains(where: { component in component.count > NAME_MAX }) {
            return false
        }

        return true
    }
}
