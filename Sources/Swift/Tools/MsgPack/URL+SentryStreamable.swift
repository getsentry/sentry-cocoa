extension URL: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(url: self)
    }

    func streamSize() -> Int {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            SentrySDKLog.error("Could not read file attributes - File: \(self) - Error: \(error)")
            return -1
        }
        guard let fileSize = attributes[.size] as? NSNumber else {
            SentrySDKLog.error("Could not read file size attribute - File: \(self)")
            return -1
        }
        let unsignedSize = fileSize.uintValue
        // Handle potential overflow for very large files
        return unsignedSize > Int.max ? Int.max : Int(unsignedSize)
    }
}
