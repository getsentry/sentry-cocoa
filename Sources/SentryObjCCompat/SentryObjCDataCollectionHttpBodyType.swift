#if SDK_V10
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public typealias SentryObjCDataCollectionHttpBodyType = UInt

extension SentryObjCDataCollectionHttpBodyType {
    init(_ underlying: SentryDataCollection.HttpBodyType) {
        self = UInt(underlying.rawValue)
    }

    var underlying: SentryDataCollection.HttpBodyType {
        SentryDataCollection.HttpBodyType(rawValue: Int(self))
    }
}

// swiftlint:enable missing_docs
#endif // SDK_V10
