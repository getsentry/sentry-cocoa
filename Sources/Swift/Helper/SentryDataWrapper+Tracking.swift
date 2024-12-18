@_implementationOnly import _SentryPrivate

let SENTRY_TRACE_ORIGIN_AUTO_SWIFT_DATA = "auto.file.swift_data"
let SENTRY_TRACKING_COUNTER_KEY = "SENTRY_TRACKING_COUNTER_KEY"
let SENTRY_FILE_WRITE_OPERATION = "file.write"
let SENTRY_FILE_READ_OPERATION = "file.read"

@available(iOS 18, macOS 15, tvOS 18, *)
extension SentryDataWrapper {
    static func startTracking(readingFileUrl url: URL) -> (any Span)? {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.isFileURL else {
            return nil
        }
        return startTracking(readingFilePath: url.path)
    }

    static func startTracking(readingFilePath path: String) -> (any Span)? {
        let count = Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] as? Int ?? 0
        Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] = count + 1

        if count > 0 {
            return nil
        }

        return Self.spanForPath(path: path, operation: SENTRY_FILE_READ_OPERATION, size: 0)
    }

    static func startTracking(writingData data: Data, toUrl url: URL, options: Data.WritingOptions) -> (any Span)? {
        return startTracking(writingData: data, toPath: url.path, options: options)
    }

    static func startTracking(writingData data: Data, toPath path: String, options: Data.WritingOptions) -> (any Span)? {
        let count = Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] as? Int ?? 0
        Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] = count + 1

        if count > 0 {
            return nil
        }

        return Self.spanForPath(
            path: path,
            operation: SENTRY_FILE_WRITE_OPERATION,
            size: UInt(data.count)
        )
    }

    static func spanForPath(path: String, operation: String, size: UInt) -> (any Span)? {
        if Self.ignoreFile(atPath: path) {
            return nil
        }

        var ioSpan: (any Span)?
        SentrySDK.currentHub().scope.useSpan { span in
            ioSpan = span?
                .startChild(
                    operation: operation,
                    description: Self
                        .transactionDescription(
                            forFileAtPath: path,
                            withFileSize: size
                        )
                )
            ioSpan?.origin = SENTRY_TRACE_ORIGIN_AUTO_SWIFT_DATA
        }
        ioSpan?.setData(value: path, key: "file.path")

        return ioSpan
    }

    static func ignoreFile(atPath path: String) -> Bool {
        guard let client = SentrySDK.currentHub().getClient() else {
            return false
        }
        return path.hasPrefix(client.fileManager.sentryPath)
    }

    static func transactionDescription(forFileAtPath path: String, withFileSize size: UInt) -> String {
        let lastPathComponent = URL(string: path)?.lastPathComponent ?? "nil"
        guard size > 0 else {
            return lastPathComponent
        }
        return String(
            format: "%@ (%@)",
            lastPathComponent,
            SentryByteCountFormatter.bytesCountDescription(size)
        )
    }

    static func finishTracking(span: (any Span)?, withData data: Data) {
        if let span = span {
            span.setData(value: NSNumber(value: data.count), key: "file.size")
            span.finish()
        }
        guard let count = Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] as? Int else {
            return
        }
        Thread.current.threadDictionary[SENTRY_TRACKING_COUNTER_KEY] = count > 1 ? count - 1 : nil
    }
}
