protocol SentryStreamable {
    func asInputStream() -> InputStream?
    func streamSize() -> Int
}
