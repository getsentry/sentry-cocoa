// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionHttpHeaderCollectionOptions)
public final class SentryObjCDataCollectionHttpHeaderCollectionOptions: NSObject {
    private var box: Box<SentryDataCollection.HttpHeaderCollectionOptions>

    internal var wrapped: SentryDataCollection.HttpHeaderCollectionOptions {
        box.value
    }

    internal init(_ wrapped: SentryDataCollection.HttpHeaderCollectionOptions) {
        self.box = Box(wrapped)
    }

    @objc public override init() {
        self.box = Box(SentryDataCollection.HttpHeaderCollectionOptions())
    }

    @objc public var request: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(box.value.request) }
        set {
            var value = box.value
            value.request = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var response: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(box.value.response) }
        set {
            var value = box.value
            value.response = newValue.wrapped
            box = Box(value)
        }
    }
}

// swiftlint:enable missing_docs
