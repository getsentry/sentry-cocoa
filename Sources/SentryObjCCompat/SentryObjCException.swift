// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCException) public final class SentryObjCException: NSObject {
    internal let wrapped: Exception

    internal init(_ wrapped: Exception) {
        self.wrapped = wrapped
    }

    @objc public init(value: String?, type: String?) {
        self.wrapped = Exception(value: value, type: type)
    }

    @objc public var value: String? {
        get { wrapped.value }
        set { wrapped.value = newValue }
    }

    @objc public var type: String? {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var mechanism: SentryObjCMechanism? {
        get {
            guard let m = wrapped.mechanism else { return nil }
            return SentryObjCMechanism(m)
        }
        set { wrapped.mechanism = newValue?.wrapped }
    }

    @objc(module) public var module: String? {
        get { wrapped.module }
        set { wrapped.module = newValue }
    }

    @objc public var threadId: NSNumber? {
        get { wrapped.threadId }
        set { wrapped.threadId = newValue }
    }

    @objc public var stacktrace: SentryObjCStacktrace? {
        get {
            guard let st = wrapped.stacktrace else { return nil }
            return SentryObjCStacktrace(st)
        }
        set { wrapped.stacktrace = newValue?.wrapped }
    }
}

// swiftlint:enable missing_docs
