@_implementationOnly import _SentryPrivate

/// A ``Data`` extension that tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original ``Data`` methods, but they track the operation with Sentry.
public extension Data {

    // MARK: - Reading Data from a File

    /// Creates a data object from the data at the specified file URL, tracking the operation with Sentry.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableDataSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - url: The location on disk of the data to read.
    ///   - options: The mask specifying the options to use when reading the data. For more information, see ``NSData.ReadingOptions``.
    /// - Note: See ``Data.init(contentsOf:options:)`` for more information.
    init(contentsOfUrlWithSentryTracing url: URL, options: Data.ReadingOptions = []) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        self = try tracker
            .measureReadingData(
                from: url,
                options: options,
                origin: SentryTraceOrigin.manualFileData) { url, options in
                    try Data(contentsOf: url, options: options)
            }
    }

    // MARK: - Writing Data to a File

    /// Write the contents of the `Data` to a location, tracking the operation with Sentry.
    /// 
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableDataSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - url: The location to write the data into.
    ///   - options: Options for writing the data. Default value is `[]`.
    /// - Note: See ``Data.write(to:options:)`` for more information.
    func writeWithSentryTracing(to url: URL, options: Data.WritingOptions = []) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        try tracker
            .measureWritingData(
                self,
                to: url,
                options: options,
                origin: SentryTraceOrigin.manualFileData) { data, url, options in
                    try data.write(to: url, options: options)
            }
    }
}
