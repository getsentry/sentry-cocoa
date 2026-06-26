// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@objc
@_spi(Private) public enum SentryANRType: Int {
    case fatalFullyBlocking
    case fatalNonFullyBlocking
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}

extension SentryANRType {
    static func fromInternal(internal: SentryANRTypeInternal) -> SentryANRType {
        switch `internal` {
        case SentryANRTypeInternal.fatalFullyBlocking:
            return .fatalFullyBlocking
        case SentryANRTypeInternal.fatalNonFullyBlocking:
            return .fatalNonFullyBlocking
        case SentryANRTypeInternal.fullyBlocking:
            return .fullyBlocking
        case SentryANRTypeInternal.nonFullyBlocking:
            return .nonFullyBlocking
        case SentryANRTypeInternal.unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
// swiftlint:enable missing_docs
