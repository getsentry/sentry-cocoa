@_implementationOnly import Sentry
import Foundation

/// A thread captured as part of an event payload.
@objc(SOCSentryThread)
public final class Thread: NSObject {
    internal let wrapped: Sentry.SentryThread

    internal init(_ wrapped: Sentry.SentryThread) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(threadId: NSNumber?) {
        self.wrapped = Sentry.SentryThread(threadId: threadId)
        super.init()
    }

    @objc public var threadId: NSNumber? {
        get { wrapped.threadId }
        set { wrapped.threadId = newValue }
    }

    @objc public var name: String? {
        get { wrapped.name }
        set { wrapped.name = newValue }
    }

    @objc public var stacktrace: Stacktrace? {
        get { wrapped.stacktrace.map(Stacktrace.init) }
        set { wrapped.stacktrace = newValue?.wrapped }
    }

    @objc public var crashed: NSNumber? {
        get { wrapped.crashed }
        set { wrapped.crashed = newValue }
    }

    @objc public var current: NSNumber? {
        get { wrapped.current }
        set { wrapped.current = newValue }
    }

    @objc public var isMain: NSNumber? {
        get { wrapped.isMain }
        set { wrapped.isMain = newValue }
    }
}
