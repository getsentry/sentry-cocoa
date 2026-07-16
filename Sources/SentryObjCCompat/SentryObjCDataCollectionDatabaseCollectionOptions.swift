#if SDK_V10
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionDatabaseCollectionOptions)
public final class SentryObjCDataCollectionDatabaseCollectionOptions: NSObject {
    private let storage: Accessor<SentryDataCollection.DatabaseCollectionOptions>

    internal var wrapped: SentryDataCollection.DatabaseCollectionOptions {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(_ storage: Accessor<SentryDataCollection.DatabaseCollectionOptions>) {
        self.storage = storage
    }

    internal init(_ wrapped: SentryDataCollection.DatabaseCollectionOptions) {
        self.storage = Accessor(wrapped)
    }

    @objc public override init() {
        self.storage = Accessor(SentryDataCollection.DatabaseCollectionOptions())
    }

    @objc public var urlQueryParams: Bool {
        get { storage.value.urlQueryParams }
        set { storage.value.urlQueryParams = newValue }
    }
}

// swiftlint:enable missing_docs
#endif // SDK_V10
