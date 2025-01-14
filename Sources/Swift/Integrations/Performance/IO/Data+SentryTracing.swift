@_implementationOnly import _SentryPrivate

/// A `Data` extension that automatically tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original `Data` methods,
///         but they automatically track the operation with Sentry.
@available(iOS 18, macOS 15, tvOS 18, *)
public extension Data {

    /// Initialize a `Data` with the contents of a `URL`, automatically tracking the operation with Sentry.
    ///
    /// - parameter url: The `URL` to read.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if `url` cannot be read.
    init(contentsOfUrlWithSentryTracing url: URL, options: Data.ReadingOptions = []) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        // Using the bridging of `Data` to `NSData` caused issues on older versions of macOS.
        // Therefore we do not use the `measureNSData` method.
        self = try tracker
            .measureReadingData(
                from: url,
                options: options,
                origin: SentryTraceOrigin.manualData) { url, options in
                    try Data(contentsOf: url, options: options)
            }
    }

    /// Write the contents of the `Data` to a location, automatically tracking the operation with Sentry.
    ///
    /// - parameter url: The location to write the data into.
    /// - parameter options: Options for writing the data. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if there is an error writing to the `URL`.
    func writeWithSentryTracing(to url: URL, options: Data.WritingOptions = []) throws {
        let tracker = SentryFileIOTracker.sharedInstance()
        // Using the bridging of `Data` to `NSData` caused issues on older versions of macOS.
        // Therefore we do not use the `measureNSData` method.
        try tracker
            .measureWritingData(
                self,
                to: url,
                options: options,
                origin: SentryTraceOrigin.manualData) { data, url, options in
                    try data.write(to: url, options: options)
            }
    }
}
