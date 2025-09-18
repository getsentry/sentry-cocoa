extension NSURL: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(url: self as URL)
    }
    
    func streamSize() -> Int {
        guard let path = self.path else {
            SentrySDKLog.debug("File URL has no path - File: \(self)")
            return -1
        }
        
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            SentrySDKLog.error("Could not read file attributes - File: \(self) - \(error)")
            return -1
        }
        guard let fileSize = attributes[.size] as? NSNumber else {
            SentrySDKLog.error("Could not read file size attribute - File: \(self)")
            return -1
        }
        return fileSize.intValue
    }
}
