@_implementationOnly import Sentry
import Foundation

/// Approximate geographic location of the end user or device.
@objc(SOCSentryGeo)
public final class Geo: NSObject {
    internal let wrapped: Sentry.Geo

    internal init(_ wrapped: Sentry.Geo) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.Geo()
        super.init()
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

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Geo else { return false }
        return wrapped.isEqual(to: other.wrapped)
    }

    public override var hash: Int { wrapped.hash }
}
