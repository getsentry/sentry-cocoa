@_implementationOnly import _SentryPrivate

extension SentryFileIOTracker {
    func measureReadingData(
        from url: URL,
        options: Data.ReadingOptions,
        origin: String,
        method: (_ url: URL, _ options: Data.ReadingOptions) throws -> Data
    ) throws -> Data {
        guard url.scheme == NSURLFileScheme else {
            return try method(url, options)
        }
        let span = self.startTrackingReadingFilePath(url.path, origin: origin)
        defer {
            self.endTrackingFile()
        }
        let result = try method(url, options)
        if let span = span {
            self.finishTrackingNSData(result, span: span)
        }
        return result
    }

    func measureWritingData(
        _ data: Data,
        to url: URL,
        options: Data.WritingOptions,
        origin: String,
        method: (_ data: Data, _ url: URL, _ options: Data.WritingOptions) throws -> Void
    ) throws {
        guard url.scheme == NSURLFileScheme else {
            return try method(data, url, options)
        }
        let span = self.startTrackingWriting(data, filePath: url.path, origin: origin)
        defer {
            self.endTrackingFile()
        }
        defer {
            if let span = span {
                self.finishTrackingNSData(data, span: span)
            }
        }
        try method(data, url, options)
    }

    func measureRemovingItem(
        at url: URL,
        origin: String,
        method: (_ url: URL) throws -> Void
    ) throws {
        guard url.scheme == NSURLFileScheme else {
            return try method(url)
        }
        let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperation.fileDelete, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
        }
        try method(url)
    }
    
    func measureRemovingItem(
        atPath path: String,
        origin: String,
        method: (_ path: String) throws -> Void
    ) throws {
        let span = self.span(forPath: path, origin: origin, operation: SentrySpanOperation.fileDelete, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
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
        let span = self.startTrackingWriting(data ?? Data(), filePath: path, origin: origin)
        defer {
            self.endTrackingFile()
        }
        defer {
            if let span = span {
                self.finishTrackingNSData(data ?? Data(), span: span)
            }
        }
        return method(path, data, attr)
    }

    func measureCopyingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) throws {
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperation.fileCopy, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
        }
        try method(srcUrl, dstUrl)
    }
    
    func measureCopyingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) throws {
        let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperation.fileCopy, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
        }
        try method(srcPath, dstPath)
    }

    func measureMovingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) throws {
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperation.fileRename, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
        }
        try method(srcUrl, dstUrl)
    }

    func measureMovingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) throws {
        let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperation.fileRename, size: 0)
        defer {
            self.endTrackingFile()
        }
        defer {
            span?.finish()
        }
        try method(srcPath, dstPath)
    }
}
