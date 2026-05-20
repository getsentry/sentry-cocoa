@_implementationOnly import Sentry
import Foundation

/// Information about an HTTP request attached to an event.
@objc(SOCSentryRequest)
public final class Request: NSObject {
    internal let wrapped: Sentry.SentryRequest

    internal init(_ wrapped: Sentry.SentryRequest) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.SentryRequest()
        super.init()
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
