// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCMechanism) public final class SentryObjCMechanism: NSObject {
    internal let wrapped: Mechanism

    internal init(_ wrapped: Mechanism) {
        self.wrapped = wrapped
    }

    @objc public init(type: String) {
        self.wrapped = Mechanism(type: type)
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

    @objc public var meta: SentryObjCMechanismContext? {
        get {
            guard let m = wrapped.meta else { return nil }
            return SentryObjCMechanismContext(m)
        }
        set { wrapped.meta = newValue?.wrapped }
    }
}

// swiftlint:enable missing_docs
