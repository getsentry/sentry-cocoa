// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCGeo: NSObject {
    internal let wrapped: Geo

    internal init(_ wrapped: Geo) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Geo()
    }

    @objc public var city: String? {
        get { wrapped.city }
        set { wrapped.city = newValue }
    }

    @objc public var countryCode: String? {
        get { wrapped.countryCode }
        set { wrapped.countryCode = newValue }
    }

    @objc public var region: String? {
        get { wrapped.region }
        set { wrapped.region = newValue }
    }
}

// swiftlint:enable missing_docs
