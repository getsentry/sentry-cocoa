// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionOptions)
public final class SentryObjCDataCollectionOptions: NSObject {
    private var box: Box<SentryDataCollection.Options>

    internal var wrapped: SentryDataCollection.Options {
        box.value
    }

    internal init(_ wrapped: SentryDataCollection.Options) {
        self.box = Box(wrapped)
    }

    @objc public override init() {
        self.box = Box(SentryDataCollection.Options())
    }

    @objc public var userInfo: Bool {
        get { box.value.userInfo }
        set {
            var value = box.value
            value.userInfo = newValue
            box = Box(value)
        }
    }

    @objc public var cookies: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(box.value.cookies) }
        set {
            var value = box.value
            value.cookies = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var httpHeaders: SentryObjCDataCollectionHttpHeaderCollectionOptions {
        get { SentryObjCDataCollectionHttpHeaderCollectionOptions(box.value.httpHeaders) }
        set {
            var value = box.value
            value.httpHeaders = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var httpBodies: SentryObjCDataCollectionHttpBodyType {
        get { SentryObjCDataCollectionHttpBodyType(box.value.httpBodies) }
        set {
            var value = box.value
            value.httpBodies = newValue.underlying
            box = Box(value)
        }
    }

    @objc public var queryParams: SentryObjCDataCollectionKeyValueCollectionBehavior {
        get { SentryObjCDataCollectionKeyValueCollectionBehavior(box.value.queryParams) }
        set {
            var value = box.value
            value.queryParams = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var graphql: SentryObjCDataCollectionGraphQLCollectionOptions {
        get { SentryObjCDataCollectionGraphQLCollectionOptions(box.value.graphql) }
        set {
            var value = box.value
            value.graphql = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var database: SentryObjCDataCollectionDatabaseCollectionOptions {
        get { SentryObjCDataCollectionDatabaseCollectionOptions(box.value.database) }
        set {
            var value = box.value
            value.database = newValue.wrapped
            box = Box(value)
        }
    }

    @objc public var stackFrameVariables: Bool {
        get { box.value.stackFrameVariables }
        set {
            var value = box.value
            value.stackFrameVariables = newValue
            box = Box(value)
        }
    }

    @objc public var frameContextLines: UInt {
        get { box.value.frameContextLines }
        set {
            var value = box.value
            value.frameContextLines = newValue
            box = Box(value)
        }
    }
}

// swiftlint:enable missing_docs
