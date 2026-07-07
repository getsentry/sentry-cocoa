// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionDatabaseCollectionOptions)
public final class SentryObjCDataCollectionDatabaseCollectionOptions: NSObject {
    private var box: Box<SentryDataCollection.DatabaseCollectionOptions>

    internal var wrapped: SentryDataCollection.DatabaseCollectionOptions {
        box.value
    }

    internal init(_ wrapped: SentryDataCollection.DatabaseCollectionOptions) {
        self.box = Box(wrapped)
    }

    @objc public override init() {
        self.box = Box(SentryDataCollection.DatabaseCollectionOptions())
    }

    @objc public var queryParams: Bool {
        get { box.value.queryParams }
        set {
            var value = box.value
            value.queryParams = newValue
            box = Box(value)
        }
    }
}

// swiftlint:enable missing_docs
