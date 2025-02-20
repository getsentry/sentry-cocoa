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

    func measureRemovingItem(
        at url: URL,
        origin: String,
        method: (_ url: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(url)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperation.fileDelete) else {
            return try method(url)
        }
        defer {
            span.finish()
        }
        try method(url)
    }
    
    func measureRemovingItem(
        atPath path: String,
        origin: String,
        method: (_ path: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: path, origin: origin, operation: SentrySpanOperation.fileDelete) else {
            return try method(path)
        }
        defer {
            span.finish()
        }
        try method(path)
    }

    func measureCreatingFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?,
        origin: String,
        method: (_ path: String, _ data: Data?, _ attributes: [FileAttributeKey: Any]?) -> Bool
    ) -> Bool {
        let size = UInt(data?.count ?? 0)
        guard let span = self.span(forPath: path, origin: origin, operation: SentrySpanOperation.fileWrite, size: size) else {
            return method(path, data, attr)
        }
        defer {
            if let data = data {
                span.setData(value: data.count, key: SentrySpanDataKey.fileSize)
            }
            span.finish()
        }
        return method(path, data, attr)
    }

    func measureCopyingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        guard let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperation.fileCopy) else {
            return try method(srcUrl, dstUrl)
        }
        defer {
            span.finish()
        }
        try method(srcUrl, dstUrl)
    }
    
    func measureCopyingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperation.fileCopy) else {
            return try method(srcPath, dstPath)
        }
        defer {
            span.finish()
        }
        try method(srcPath, dstPath)
    }

    func measureMovingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        guard let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperation.fileRename) else {
            return try method(srcUrl, dstUrl)
        }
        defer {
            span.finish()
        }
        try method(srcUrl, dstUrl)
    }

    func measureMovingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperation.fileRename) else {
            return try method(srcPath, dstPath)
        }
        defer {
            span.finish()
        }
        try method(srcPath, dstPath)
    }
}
