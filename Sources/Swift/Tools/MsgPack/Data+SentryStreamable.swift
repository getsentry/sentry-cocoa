extension Data: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(data: self)
    }

    func streamSize() -> UInt? {
        return UInt(self.count)
    }
}
