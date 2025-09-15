extension Data: SentryStreamable {
    func asInputStream() -> InputStream? {
        return InputStream(data: self)
    }

    func streamSize() -> Int {
        return self.count
    }
}
