extension NSData: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(data: self as Data)
    }
    
    func streamSize() -> Int {
        return self.length
    }
}
