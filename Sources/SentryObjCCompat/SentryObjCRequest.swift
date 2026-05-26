// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCRequest) public final class SentryObjCRequest: NSObject {
    internal let wrapped: SentryRequest

    internal init(_ wrapped: SentryRequest) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryRequest()
    }

    @objc public var bodySize: NSNumber? {
        get { wrapped.bodySize }
        set { wrapped.bodySize = newValue }
    }

    @objc public var cookies: String? {
        get { wrapped.cookies }
        set { wrapped.cookies = newValue }
    }

    @objc public var headers: [String: String]? {
        get { wrapped.headers }
        set { wrapped.headers = newValue }
    }

    @objc public var fragment: String? {
        get { wrapped.fragment }
        set { wrapped.fragment = newValue }
    }

    @objc public var method: String? {
        get { wrapped.method }
        set { wrapped.method = newValue }
    }

    @objc public var queryString: String? {
        get { wrapped.queryString }
        set { wrapped.queryString = newValue }
    }

    @objc public var url: String? {
        get { wrapped.url }
        set { wrapped.url = newValue }
    }
}

// swiftlint:enable missing_docs
