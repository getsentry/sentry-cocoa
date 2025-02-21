@_implementationOnly import _SentryPrivate

extension SentryFileIOTracker {
    func measureReadingData(
        from url: URL,
        options: Data.ReadingOptions,
        origin: String,
        method: (_ url: URL, _ options: Data.ReadingOptions) throws -> Data
    ) rethrows -> Data {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(url, options)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperation.fileRead) else {
            return try method(url, options)
        }
        defer {
            span.finish()
        }
        let data = try method(url, options)
        span.setData(value: data.count, key: SentrySpanDataKey.fileSize)
        return data
    }

    func measureWritingData(
        _ data: Data,
        to url: URL,
        options: Data.WritingOptions,
        origin: String,
        method: (_ data: Data, _ url: URL, _ options: Data.WritingOptions) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(data, url, options)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperation.fileWrite, size: UInt(data.count)) else {
            return try method(data, url, options)
        }
        defer {
            span.finish()
        }
        try method(data, url, options)
    }
}
