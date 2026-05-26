// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCThread: NSObject {
    internal let wrapped: SentryThread

    internal init(_ wrapped: SentryThread) {
        self.wrapped = wrapped
    }

    @objc public init(threadId: NSNumber?) {
        self.wrapped = SentryThread(threadId: threadId)
    }

    @objc public var threadId: NSNumber? {
        get { wrapped.threadId }
        set { wrapped.threadId = newValue }
    }

    @objc public var name: String? {
        get { wrapped.name }
        set { wrapped.name = newValue }
    }

    @objc public var stacktrace: SentryObjCStacktrace? {
        get {
            guard let st = wrapped.stacktrace else { return nil }
            return SentryObjCStacktrace(st)
        }
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

// swiftlint:enable missing_docs
