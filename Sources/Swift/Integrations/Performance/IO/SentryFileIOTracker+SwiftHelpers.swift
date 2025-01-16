@_implementationOnly import _SentryPrivate

extension SentryFileIOTracker {
    func measureReadingData(from url: URL, options: Data.ReadingOptions, origin: String, method: (_ url: URL, _ options: Data.ReadingOptions) throws -> Data) throws -> Data {
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
            if let span = span {
                self.finishTrackingNSData(data, span: span)
            }
        }
        try method(data, url, options)
    }
}
