// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCMechanismContext) public final class SentryObjCMechanismContext: NSObject {
    internal let wrapped: MechanismContext

    internal init(_ wrapped: MechanismContext) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = MechanismContext()
    }

    @objc public var signal: [String: Any]? {
        get { wrapped.signal }
        set { wrapped.signal = newValue }
    }

    @objc public var machException: [String: Any]? {
        get { wrapped.machException }
        set { wrapped.machException = newValue }
    }

    @objc public var error: SentryObjCNSError? {
        get {
            guard let e = wrapped.error else { return nil }
            return SentryObjCNSError(e)
        }
        set { wrapped.error = newValue?.wrapped }
    }
}

// swiftlint:enable missing_docs
