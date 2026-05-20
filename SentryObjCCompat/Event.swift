// swiftlint:disable file_length
@_implementationOnly import Sentry
import Foundation

/// A Sentry event payload.
@objc(SentryCompatEvent)
public final class Event: NSObject {
    internal let wrapped: Sentry.Event

    internal init(_ wrapped: Sentry.Event) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = Sentry.Event()
        super.init()
    }

    @objc public init(level: SentryLevel) {
        self.wrapped = Sentry.Event(level: level.underlying)
        super.init()
    }

    @objc public init(error: Error) {
        self.wrapped = Sentry.Event(error: error)
        super.init()
    }

    @objc public var eventId: SentryId {
        get { SentryId(wrapped.eventId) }
        set { wrapped.eventId = newValue.wrapped }
    }

    @objc public var message: Message? {
        get { wrapped.message.map(Message.init) }
        set { wrapped.message = newValue?.wrapped }
    }

    @objc public var error: Error? {
        get { wrapped.error }
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

    @objc public var level: SentryLevel {
        get { SentryLevel(wrapped.level) }
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

    @objc public var user: User? {
        get { wrapped.user.map(User.init) }
        set { wrapped.user = newValue?.wrapped }
    }

    @objc public var context: [String: [String: Any]]? {
        get { wrapped.context }
        set { wrapped.context = newValue }
    }

    @objc public var threads: [Thread]? {
        get { wrapped.threads?.map(Thread.init) }
        set { wrapped.threads = newValue?.map { $0.wrapped } }
    }

    @objc public var exceptions: [Exception]? {
        get { wrapped.exceptions?.map(Exception.init) }
        set { wrapped.exceptions = newValue?.map { $0.wrapped } }
    }

    @objc public var stacktrace: Stacktrace? {
        get { wrapped.stacktrace.map(Stacktrace.init) }
        set { wrapped.stacktrace = newValue?.wrapped }
    }

    @objc public var debugMeta: [DebugMeta]? {
        get { wrapped.debugMeta?.map(DebugMeta.init) }
        set { wrapped.debugMeta = newValue?.map { $0.wrapped } }
    }

    @objc public var breadcrumbs: [Breadcrumb]? {
        get { wrapped.breadcrumbs?.map(Breadcrumb.init) }
        set { wrapped.breadcrumbs = newValue?.map { $0.wrapped } }
    }

    @objc public var request: Request? {
        get { wrapped.request.map(Request.init) }
        set { wrapped.request = newValue?.wrapped }
    }
}
// swiftlint:enable file_length
