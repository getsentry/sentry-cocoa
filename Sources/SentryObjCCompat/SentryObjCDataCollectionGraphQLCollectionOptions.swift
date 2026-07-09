// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionGraphQLCollectionOptions)
public final class SentryObjCDataCollectionGraphQLCollectionOptions: NSObject {
    private let storage: Accessor<SentryDataCollection.GraphQLCollectionOptions>

    internal var wrapped: SentryDataCollection.GraphQLCollectionOptions {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(_ storage: Accessor<SentryDataCollection.GraphQLCollectionOptions>) {
        self.storage = storage
    }

    internal init(_ wrapped: SentryDataCollection.GraphQLCollectionOptions) {
        self.storage = Accessor(wrapped)
    }

    @objc public override init() {
        self.storage = Accessor(SentryDataCollection.GraphQLCollectionOptions())
    }

    @objc public var document: Bool {
        get { storage.value.document }
        set { storage.value.document = newValue }
    }

    @objc public var variables: Bool {
        get { storage.value.variables }
        set { storage.value.variables = newValue }
    }
}

// swiftlint:enable missing_docs
