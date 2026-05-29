// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCBreadcrumb) public final class SentryObjCBreadcrumb: NSObject {
    internal let wrapped: Breadcrumb

    internal init(_ wrapped: Breadcrumb) {
        self.wrapped = wrapped
    }

    @objc public init(level: SentryObjCLevel, category: String) {
        self.wrapped = Breadcrumb(level: level.underlying, category: category)
    }

    @objc public override init() {
        self.wrapped = Breadcrumb()
    }

    @objc public var level: SentryObjCLevel {
        get { SentryObjCLevel(wrapped.level) }
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
}

// swiftlint:enable missing_docs
