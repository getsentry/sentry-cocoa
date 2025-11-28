@_implementationOnly import _SentryPrivate
import Foundation

/// A ``FileHandle`` extension that tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original ``FileHandle`` methods, but they track the operation with Sentry.
public extension FileHandle {

    // MARK: - Reading Data from a FileHandle

    /// Reads data synchronously up to the specified number of bytes, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileHandle.readData(ofLength:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.enableFileHandleSwizzling` to `false` when initializing Sentry.
    /// - Parameter length: The maximum number of bytes to read.
    /// - Returns: The data read from the file handle.
    /// - Note: See ``FileHandle.readData(ofLength:)`` for more information.
    /// - Note: This method only tracks file handles that have a file path (e.g., regular files). Pipes, sockets, and other non-file handles are not tracked.
    func readDataWithSentryTracing(ofLength length: Int) throws -> Data {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (fileHandle: FileHandle, length: UInt) throws -> Data in
            try fileHandle.readData(ofLength: length)
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(self, UInt(length))
        }
        return try tracker
            .measureReadingFileHandle(
                self,
                ofLength: UInt(length),
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }

    /// Reads the remaining data synchronously from the file handle to the end of the file, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileHandle.readDataToEndOfFile()`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.enableFileHandleSwizzling` to `false` when initializing Sentry.
    /// - Returns: The data read from the file handle.
    /// - Note: See ``FileHandle.readDataToEndOfFile()`` for more information.
    /// - Note: This method only tracks file handles that have a file path (e.g., regular files). Pipes, sockets, and other non-file handles are not tracked.
    func readDataToEndOfFileWithSentryTracing() throws -> Data {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (fileHandle: FileHandle) throws -> Data in
            try fileHandle.readDataToEndOfFile()
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(self)
        }
        return try tracker
            .measureReadingFileHandleToEnd(
                self,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }

    // MARK: - Writing Data to a FileHandle

    /// Writes data synchronously to the file handle, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileHandle.write(_:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.enableFileHandleSwizzling` to `false` when initializing Sentry.
    /// - Parameter data: The data to write to the file handle.
    /// - Note: See ``FileHandle.write(_:)`` for more information.
    /// - Note: This method only tracks file handles that have a file path (e.g., regular files). Pipes, sockets, and other non-file handles are not tracked.
    func writeWithSentryTracing(_ data: Data) throws {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (fileHandle: FileHandle, data: Data) throws in
            try fileHandle.write(data)
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(self, data)
        }
        try tracker
            .measureWritingFileHandle(
                self,
                data: data,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }

    /// Synchronizes the file handle's in-memory state with the on-disk file, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileHandle.synchronizeFile()`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.enableFileHandleSwizzling` to `false` when initializing Sentry.
    /// - Note: See ``FileHandle.synchronizeFile()`` for more information.
    /// - Note: This method only tracks file handles that have a file path (e.g., regular files). Pipes, sockets, and other non-file handles are not tracked.
    func synchronizeFileWithSentryTracing() throws {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (fileHandle: FileHandle) throws in
            try fileHandle.synchronizeFile()
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(self)
        }
        try tracker
            .measureSynchronizingFileHandle(
                self,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }
}
