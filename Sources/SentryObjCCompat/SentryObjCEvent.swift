// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCEvent) public final class SentryObjCEvent: NSObject {
    internal let wrapped: Event

    internal init(_ wrapped: Event) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Event()
    }

    @objc public init(level: SentryObjCLevel) {
        self.wrapped = Event(level: level.underlying)
    }

    @objc public init(error: NSError) {
        self.wrapped = Event(error: error)
    }

    @objc public var eventId: SentryObjCId {
        get { SentryObjCId(wrapped.eventId) }
        set { wrapped.eventId = newValue.wrapped }
    }

    @objc public var message: SentryObjCMessage? {
        get {
            guard let m = wrapped.message else { return nil }
            return SentryObjCMessage(m)
        }
        set { wrapped.message = newValue?.wrapped }
    }

    @objc public var error: NSError? {
        get { wrapped.error as NSError? }
        set { wrapped.error = newValue }
    }

    @objc public var timestamp: Date? {
        get { wrapped.timestamp }
        set { wrapped.timestamp = newValue }
    }

    @objc public var startTimestamp: Date? {
        get { wrapped.startTimestamp }
        set { wrapped.startTimestamp = newValue }
    }

    @objc public var level: SentryObjCLevel {
        get { SentryObjCLevel(wrapped.level) }
        set { wrapped.level = newValue.underlying }
    }

    @objc public var platform: String {
        get { wrapped.platform }
        set { wrapped.platform = newValue }
    }

    @objc public var logger: String? {
        get { wrapped.logger }
        set { wrapped.logger = newValue }
    }

    @objc public var serverName: String? {
        get { wrapped.serverName }
        set { wrapped.serverName = newValue }
    }

    @objc public var releaseName: String? {
        get { wrapped.releaseName }
        set { wrapped.releaseName = newValue }
    }

    @objc public var dist: String? {
        get { wrapped.dist }
        set { wrapped.dist = newValue }
    }

    @objc public var environment: String? {
        get { wrapped.environment }
        set { wrapped.environment = newValue }
    }

    @objc public var transaction: String? {
        get { wrapped.transaction }
        set { wrapped.transaction = newValue }
    }

    @objc public var type: String? {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var tags: [String: String]? {
        get { wrapped.tags }
        set { wrapped.tags = newValue }
    }

    @objc public var extra: [String: Any]? {
        get { wrapped.extra }
        set { wrapped.extra = newValue }
    }

    @objc public var sdk: [String: Any]? {
        get { wrapped.sdk }
        set { wrapped.sdk = newValue }
    }

    @objc public var modules: [String: String]? {
        get { wrapped.modules }
        set { wrapped.modules = newValue }
    }

    @objc public var fingerprint: [String]? {
        get { wrapped.fingerprint }
        set { wrapped.fingerprint = newValue }
    }

    @objc public var user: SentryObjCUser? {
        get {
            guard let u = wrapped.user else { return nil }
            return SentryObjCUser(u)
        }
        set { wrapped.user = newValue?.wrapped }
    }

    @objc public var context: [String: [String: Any]]? {
        get { wrapped.context }
        set { wrapped.context = newValue }
    }

    @objc public var threads: [SentryObjCThread]? {
        get {
            guard let t = wrapped.threads else { return nil }
            return t.map { SentryObjCThread($0) }
        }
        set { wrapped.threads = newValue?.map(\.wrapped) }
    }

    @objc public var exceptions: [SentryObjCException]? {
        get {
            guard let e = wrapped.exceptions else { return nil }
            return e.map { SentryObjCException($0) }
        }
        set { wrapped.exceptions = newValue?.map(\.wrapped) }
    }

    @objc public var stacktrace: SentryObjCStacktrace? {
        get {
            guard let st = wrapped.stacktrace else { return nil }
            return SentryObjCStacktrace(st)
        }
        set { wrapped.stacktrace = newValue?.wrapped }
    }

    @objc public var debugMeta: [SentryObjCDebugMeta]? {
        get {
            guard let d = wrapped.debugMeta else { return nil }
            return d.map { SentryObjCDebugMeta($0) }
        }
        set { wrapped.debugMeta = newValue?.map(\.wrapped) }
    }

    @objc public var breadcrumbs: [SentryObjCBreadcrumb]? {
        get {
            guard let b = wrapped.breadcrumbs else { return nil }
            return b.map { SentryObjCBreadcrumb($0) }
        }
        set { wrapped.breadcrumbs = newValue?.map(\.wrapped) }
    }

    @objc public var request: SentryObjCRequest? {
        get {
            guard let r = wrapped.request else { return nil }
            return SentryObjCRequest(r)
        }
        set { wrapped.request = newValue?.wrapped }
    }
}

// swiftlint:enable missing_docs
