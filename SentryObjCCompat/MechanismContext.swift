@_implementationOnly import Sentry
import Foundation

/// Platform-specific error context attached to an exception mechanism.
@objc(SentryCompatMechanismContext)
public final class MechanismContext: NSObject {
    internal let wrapped: Sentry.MechanismContext

    internal init(_ wrapped: Sentry.MechanismContext) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.MechanismContext()
        super.init()
    }

    @objc public var signal: [String: Any]? {
        get { wrapped.signal }
        set { wrapped.signal = newValue }
    }

    @objc public var machException: [String: Any]? {
        get { wrapped.machException }
        set { wrapped.machException = newValue }
    }

    // The underlying `error` property is typed as `SentryNSError` — we don't
    // wrap that type yet, so this slot is omitted from the public surface in
    // this pass.
    // TODO: wrap SentryNSError to expose `error`
}
