@_implementationOnly import Sentry
import Foundation

/// Metadata describing how an exception was reported.
@objc(SentryCompatMechanism)
public final class Mechanism: NSObject {
    internal let wrapped: Sentry.Mechanism

    internal init(_ wrapped: Sentry.Mechanism) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(type: String) {
        self.wrapped = Sentry.Mechanism(type: type)
        super.init()
    }

    @objc public var type: String {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var desc: String? {
        get { wrapped.desc }
        set { wrapped.desc = newValue }
    }

    @objc public var data: [String: Any]? {
        get { wrapped.data }
        set { wrapped.data = newValue }
    }

    @objc public var handled: NSNumber? {
        get { wrapped.handled }
        set { wrapped.handled = newValue }
    }

    @objc public var synthetic: NSNumber? {
        get { wrapped.synthetic }
        set { wrapped.synthetic = newValue }
    }

    @objc public var helpLink: String? {
        get { wrapped.helpLink }
        set { wrapped.helpLink = newValue }
    }

    @objc public var meta: MechanismContext? {
        get { wrapped.meta.map(MechanismContext.init) }
        set { wrapped.meta = newValue?.wrapped }
    }
}
