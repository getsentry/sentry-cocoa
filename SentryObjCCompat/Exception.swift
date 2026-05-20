@_implementationOnly import Sentry
import Foundation

/// A captured exception with its stacktrace and mechanism metadata.
@objc(SentryCompatException)
public final class Exception: NSObject {
    internal let wrapped: Sentry.Exception

    internal init(_ wrapped: Sentry.Exception) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(value: String?, type: String?) {
        self.wrapped = Sentry.Exception(value: value, type: type)
        super.init()
    }

    @objc public var value: String? {
        get { wrapped.value }
        set { wrapped.value = newValue }
    }

    @objc public var type: String? {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var mechanism: Mechanism? {
        get { wrapped.mechanism.map(Mechanism.init) }
        set { wrapped.mechanism = newValue?.wrapped }
    }

    @objc public var module: String? {
        get { wrapped.module }
        set { wrapped.module = newValue }
    }

    @objc public var threadId: NSNumber? {
        get { wrapped.threadId }
        set { wrapped.threadId = newValue }
    }

    @objc public var stacktrace: Stacktrace? {
        get { wrapped.stacktrace.map(Stacktrace.init) }
        set { wrapped.stacktrace = newValue?.wrapped }
    }
}
