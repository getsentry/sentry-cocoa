// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public final class SentryObjCUser: NSObject {
    internal let wrapped: User

    internal init(_ wrapped: User) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = User()
    }

    @objc public init(userId: String) {
        self.wrapped = User(userId: userId)
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

    @objc public var geo: SentryObjCGeo? {
        get {
            guard let g = wrapped.geo else { return nil }
            return SentryObjCGeo(g)
        }
        set { wrapped.geo = newValue?.wrapped }
    }

    @objc public var data: [String: Any]? {
        get { wrapped.data }
        set { wrapped.data = newValue }
    }
}

// swiftlint:enable missing_docs
