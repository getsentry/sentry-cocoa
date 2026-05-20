@_implementationOnly import Sentry
import Foundation

/// User identification attached to events.
@objc(SentryCompatUser)
public final class User: NSObject {
    internal let wrapped: Sentry.User

    internal init(_ wrapped: Sentry.User) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.User()
        super.init()
    }

    @objc public init(userId: String) {
        self.wrapped = Sentry.User(userId: userId)
        super.init()
    }

    @objc public var userId: String? {
        get { wrapped.userId }
        set { wrapped.userId = newValue }
    }

    @objc public var email: String? {
        get { wrapped.email }
        set { wrapped.email = newValue }
    }

    @objc public var username: String? {
        get { wrapped.username }
        set { wrapped.username = newValue }
    }

    @objc public var ipAddress: String? {
        get { wrapped.ipAddress }
        set { wrapped.ipAddress = newValue }
    }

    @objc public var name: String? {
        get { wrapped.name }
        set { wrapped.name = newValue }
    }

    @objc public var geo: Geo? {
        get { wrapped.geo.map(Geo.init) }
        set { wrapped.geo = newValue?.wrapped }
    }

    @objc public var data: [String: Any]? {
        get { wrapped.data }
        set { wrapped.data = newValue }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? User else { return false }
        return wrapped.isEqual(to: other.wrapped)
    }

    public override var hash: Int { wrapped.hash }
}
