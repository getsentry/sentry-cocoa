import Foundation

/// Manages the installation ID for the Sentry SDK.
///
/// The installation ID is a unique identifier for the SDK installation,
/// stored in a file in the cache directory. It's used to identify the
/// device/installation across app launches.
@_spi(Private) @objc
public class SentryInstallation: NSObject {

    private static var installationStringsByCacheDirectoryPaths = [String: String]()
    private static let lock = NSRecursiveLock()

    /// Returns the installation ID for the given cache directory path.
    ///
    /// If the installation ID is cached in memory, returns it immediately.
    /// Otherwise, reads it from disk or generates a new one if it doesn't exist.
    @objc
    public static func id(withCacheDirectoryPath cacheDirectoryPath: String) -> String {
        lock.synchronized {
            if let installationString = installationStringsByCacheDirectoryPaths[cacheDirectoryPath] {
                return installationString
            }

            let installationString: String
            if let cached = idNonCached(withCacheDirectoryPath: cacheDirectoryPath) {
                installationString = cached
            } else {
                installationString = UUID().uuidString

                let installationFilePath = Self.installationFilePath(cacheDirectoryPath)

                if let data = installationString.data(using: .utf8) {
                    if !FileManager.default.createFile(atPath: installationFilePath, contents: data, attributes: nil) {
                        SentrySDKLog.error("Failed to store installationID file at path \(installationFilePath)")
                    }
                }
            }

            installationStringsByCacheDirectoryPaths[cacheDirectoryPath] = installationString
            return installationString
        }
    }

    /// Returns the installation ID from disk without using the cache.
    @objc(idWithCacheDirectoryPathNonCached:)
    public static func idNonCached(withCacheDirectoryPath cacheDirectoryPath: String) -> String? {
        let installationFilePath = Self.installationFilePath(cacheDirectoryPath)

        guard let installationData = FileManager.default.contents(atPath: installationFilePath) else {
            return nil
        }

        return String(data: installationData, encoding: .utf8)
    }

    /// Caches the installation ID asynchronously.
    ///
    /// This method dispatches the ID retrieval to a background queue to avoid
    /// blocking the main thread with file I/O operations.
    @objc
    public static func cacheIDAsync(withCacheDirectoryPath cacheDirectoryPath: String) {
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper.dispatchAsync {
            _ = Self.id(withCacheDirectoryPath: cacheDirectoryPath)
        }
    }

    /// Returns the cached installation ID if it exists in memory.
    @objc
    public static func cachedId(withCacheDirectoryPath cacheDirectoryPath: String) -> String? {
        lock.synchronized {
            installationStringsByCacheDirectoryPaths[cacheDirectoryPath]
        }
    }

    private static func installationFilePath(_ cacheDirectoryPath: String) -> String {
        (cacheDirectoryPath as NSString).appendingPathComponent("INSTALLATION")
    }

    /// Clears all cached installation IDs. For testing purposes only.
    public static func clearCachedInstallationIds() {
        lock.synchronized {
            installationStringsByCacheDirectoryPaths.removeAll()
        }
    }
}
