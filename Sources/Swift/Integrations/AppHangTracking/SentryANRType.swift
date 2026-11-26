#if !SDK_V10
// swiftlint:disable missing_docs

@objc @_spi(Private) public enum SentryANRType: Int {
    case fatalFullyBlocking
    case fatalNonFullyBlocking
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}
// swiftlint:enable missing_docs
#endif // !SDK_V10
