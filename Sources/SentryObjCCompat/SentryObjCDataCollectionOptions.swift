// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionOptions)
public final class SentryObjCDataCollectionOptions: NSObject {
    private let storage: Accessor<SentryDataCollection.Options>

    internal var wrapped: SentryDataCollection.Options {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(parent: SentryExperimentalOptions) {
        self.storage = Accessor(
            get: { parent.dataCollection },
            set: { parent.dataCollection = $0 }
        )
    }

    internal init(_ wrapped: SentryDataCollection.Options) {
        self.storage = Accessor(wrapped)
    }

    @objc public override init() {
        self.storage = Accessor(SentryDataCollection.Options())
    }

    @objc public var userInfo: Bool {
        get { storage.value.userInfo }
        set { storage.value.userInfo = newValue }
    }

    @objc public var cookies: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(storage.value.cookies) }
        set { storage.value.cookies = newValue.wrapped }
    }

    @objc public var httpHeaders: SentryObjCDataCollectionHttpHeaderCollectionOptions {
        get { SentryObjCDataCollectionHttpHeaderCollectionOptions(storage.child(\.httpHeaders)) }
        set { storage.value.httpHeaders = newValue.wrapped }
    }

    @objc public var httpBodies: SentryObjCDataCollectionHttpBodyType {
        get { SentryObjCDataCollectionHttpBodyType(storage.value.httpBodies) }
        set { storage.value.httpBodies = newValue.underlying }
    }

    @objc public var queryParams: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(storage.value.queryParams) }
        set { storage.value.queryParams = newValue.wrapped }
    }

    @objc public var graphql: SentryObjCDataCollectionGraphQLCollectionOptions {
        get { SentryObjCDataCollectionGraphQLCollectionOptions(storage.child(\.graphql)) }
        set { storage.value.graphql = newValue.wrapped }
    }

    @objc public var database: SentryObjCDataCollectionDatabaseCollectionOptions {
        get { SentryObjCDataCollectionDatabaseCollectionOptions(storage.child(\.database)) }
        set { storage.value.database = newValue.wrapped }
    }

    @objc public var stackFrameVariables: Bool {
        get { storage.value.stackFrameVariables }
        set { storage.value.stackFrameVariables = newValue }
    }

    @objc public var frameContextLines: UInt {
        get { storage.value.frameContextLines }
        set { storage.value.frameContextLines = newValue }
    }
}

// swiftlint:enable missing_docs
