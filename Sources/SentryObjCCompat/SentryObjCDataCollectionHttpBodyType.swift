// swiftlint:disable missing_docs
internal import Sentry

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
