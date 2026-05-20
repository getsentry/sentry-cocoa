internal import SentrySwift
import Foundation

/// A breadcrumb attached to a Sentry event.
@objc(SOCSentryBreadcrumb)
public final class Breadcrumb: NSObject {
    internal let wrapped: SentrySwift.Breadcrumb

    internal init(_ wrapped: SentrySwift.Breadcrumb) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = SentrySwift.Breadcrumb()
        super.init()
    }

    @objc public init(level: SentryLevel, category: String) {
        self.wrapped = SentrySwift.Breadcrumb(level: level.underlying, category: category)
        super.init()
    }

    @objc public var level: SentryLevel {
        get { SentryLevel(wrapped.level) }
        set { wrapped.level = newValue.underlying }
    }

    @objc public var category: String {
        get { wrapped.category }
        set { wrapped.category = newValue }
    }

    @objc public var timestamp: Date? {
        get { wrapped.timestamp }
        set { wrapped.timestamp = newValue }
    }

    @objc public var type: String? {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var message: String? {
        get { wrapped.message }
        set { wrapped.message = newValue }
    }

    @objc public var origin: String? {
        get { wrapped.origin }
        set { wrapped.origin = newValue }
    }

    @objc public var data: [String: Any]? {
        get { wrapped.data }
        set { wrapped.data = newValue }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Breadcrumb else { return false }
        return wrapped.isEqual(other.wrapped)
    }

    public override var hash: Int { wrapped.hash }
}
