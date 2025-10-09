extension URL: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(url: self)
    }

    func streamSize() -> UInt? {
        // Ideally this method would return an unsigned integer, however the
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            SentrySDKLog.error("Could not read file attributes - File: \(self) - Error: \(error)")
            return nil
        }
        guard let fileSize = attributes[.size] as? NSNumber else {
            SentrySDKLog.error("Could not read file size attribute - File: \(self)")
            return nil
        }
        return fileSize.uintValue
    }
}
