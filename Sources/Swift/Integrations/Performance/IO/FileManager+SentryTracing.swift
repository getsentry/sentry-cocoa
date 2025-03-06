@_implementationOnly import _SentryPrivate
import Foundation

/// A ``FileManager`` extension that tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original ``FileManager`` methods, but they track the operation with Sentry.
public extension FileManager {

    // MARK: - Creating and Deleting Items

    /// Creates a file with the specified content and attributes at the given location, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - path: The path for the new file.
    ///   - data: A data object containing the contents of the new file.
    ///   - attr: A dictionary containing the attributes to associate with the new file. 
    ///           You can use these attributes to set the owner and group numbers, file permissions, and modification date.
    ///           For a list of keys, see ``FileAttributeKey``. If you specify `nil` for attributes, the file is created with a set of default attributes.
    /// - Returns: `true` if the operation was successful or if the item already exists, otherwise `false`.
    /// - Note: See ``FileManager.createFile(atPath:contents:attributes:)`` for more information.
    func createFileWithSentryTracing(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]? = nil) -> Bool {
        let tracker = SentryFileIOTracker.sharedInstance()
        return tracker
            .measureCreatingFile(
                atPath: path,
                contents: data,
                attributes: attr,
                origin: SentryTraceOriginManualFileData) { path, data, attr in
                    self.createFile(atPath: path, contents: data, attributes: attr)
            }
    }
    
    /// Removes the file or directory at the specified URL, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameter url: A file URL specifying the file or directory to remove.
    ///                  If the URL specifies a directory, the contents of that directory are recursively removed.
    /// - Note: See ``FileManager.removeItem(at:)`` for more information.
    func removeItemWithSentryTracing(at url: URL) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureRemovingItem(at: url, origin: SentryTraceOriginManualFileData) { url in
            try self.removeItem(at: url)
        }
    }

    /// Removes the file or directory at the specified path, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameter path: A path string indicating the file or directory to remove.
    ///                   If the path specifies a directory, the contents of that directory are recursively removed.
    /// - Note: See ``FileManager.removeItem(atPath:)`` for more information.
    func removeItemWithSentryTracing(atPath path: String) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureRemovingItem(atPath: path, origin: SentryTraceOriginManualFileData) { path in
            try self.removeItem(atPath: path)
        }
    }

    // MARK: - Moving and Copying Items
    
    /// Copies the file at the specified URL to a new location synchronously, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcURL: The file URL that identifies the file you want to copy.
    ///             The URL in this parameter must not be a file reference URL.
    ///   - dstURL: The URL at which to place the copy of `srcURL`.
    ///             The URL in this parameter must not be a file reference URL and must include the name of the file in its new location.
    /// - Note: See ``FileManager.copyItem(at:to:)`` for more information.
    func copyItemWithSentryTracing(at srcURL: URL, to dstURL: URL) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureCopyingItem(at: srcURL, to: dstURL, origin: SentryTraceOriginManualFileData) { srcURL, dstURL in
            try self.copyItem(at: srcURL, to: dstURL)
        }
    }
    
    /// Copies the item at the specified path to a new location synchronously, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcPath: The path to the file or directory you want to move. 
    ///   - dstPath: The path at which to place the copy of `srcPath`. 
    ///              This path must include the name of the file or directory in its new location. 
    /// - Note: See ``FileManager.copyItem(atPath:toPath:)`` for more information.
    func copyItemWithSentryTracing(atPath srcPath: String, toPath dstPath: String) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureCopyingItem(atPath: srcPath, toPath: dstPath, origin: SentryTraceOriginManualFileData) { srcPath, dstPath in
            try self.copyItem(atPath: srcPath, toPath: dstPath)
        }
    }
    
    /// Moves the file or directory at the specified URL to a new location synchronously, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcURL: The file URL that identifies the file or directory you want to move. 
    ///             The URL in this parameter must not be a file reference URL.
    ///   - dstURL: The new location for the item in `srcURL`. 
    ///             The URL in this parameter must not be a file reference URL and must include the name of the file or directory in its new location. 
    /// - Note: See ``FileManager.moveItem(at:to:)`` for more information.
    func moveItemWithSentryTracing(at srcURL: URL, to dstURL: URL) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureMovingItem(
            at: srcURL,
            to: dstURL,
            origin: SentryTraceOriginManualFileData) { srcURL, dstURL in
            try self.moveItem(at: srcURL, to: dstURL)
        }
    }
    
    /// Moves the file or directory at the specified path to a new location synchronously, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcPath: The path to the file or directory you want to move.
    ///   - dstPath: The new path for the item in `srcPath`. 
    ///              This path must include the name of the file or directory in its new location.
    /// - Note: See ``FileManager.moveItem(atPath:toPath:)`` for more information.
    func moveItemWithSentryTracing(atPath srcPath: String, toPath dstPath: String) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker.measureMovingItem(atPath: srcPath, toPath: dstPath, origin: SentryTraceOriginManualFileData) { srcPath, dstPath in
            try self.moveItem(atPath: srcPath, toPath: dstPath)
        }
    }
}
