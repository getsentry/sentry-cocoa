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
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperationFileRead) else {
            return try method(url, options)
        }
        do {
            let data = try method(url, options)
            span.setData(value: data.count, key: SentrySpanDataKeyFileSize)
            span.finish()
            return data
        } catch {
            span.finish(status: .internalError)
            throw error
        }
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
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperationFileWrite, size: UInt(data.count)) else {
            return try method(data, url, options)
        }
        do {
            try method(data, url, options)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }
}
