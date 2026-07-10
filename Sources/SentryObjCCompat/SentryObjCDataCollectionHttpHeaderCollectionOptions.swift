// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionHttpHeaderCollectionOptions)
public final class SentryObjCDataCollectionHttpHeaderCollectionOptions: NSObject {
    private let storage: Accessor<SentryDataCollection.HttpHeaderCollectionOptions>

    internal var wrapped: SentryDataCollection.HttpHeaderCollectionOptions {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(_ storage: Accessor<SentryDataCollection.HttpHeaderCollectionOptions>) {
        self.storage = storage
    }

    internal init(_ wrapped: SentryDataCollection.HttpHeaderCollectionOptions) {
        self.storage = Accessor(wrapped)
    }

    @objc public override init() {
        self.storage = Accessor(SentryDataCollection.HttpHeaderCollectionOptions())
    }

    @objc public var request: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(storage.value.request) }
        set { storage.value.request = newValue.wrapped }
    }

    @objc public var response: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(storage.value.response) }
        set { storage.value.response = newValue.wrapped }
    }
}

// swiftlint:enable missing_docs
