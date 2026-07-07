// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionGraphQLCollectionOptions)
public final class SentryObjCDataCollectionGraphQLCollectionOptions: NSObject {
    private var box: Box<SentryDataCollection.GraphQLCollectionOptions>

    internal var wrapped: SentryDataCollection.GraphQLCollectionOptions {
        box.value
    }

    internal init(_ wrapped: SentryDataCollection.GraphQLCollectionOptions) {
        self.box = Box(wrapped)
    }

    @objc public override init() {
        self.box = Box(SentryDataCollection.GraphQLCollectionOptions())
    }

    @objc public var document: Bool {
        get { box.value.document }
        set {
            var value = box.value
            value.document = newValue
            box = Box(value)
        }
    }

    @objc public var variables: Bool {
        get { box.value.variables }
        set {
            var value = box.value
            value.variables = newValue
            box = Box(value)
        }
    }
}

// swiftlint:enable missing_docs
