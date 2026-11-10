internal import _SentryPrivate
import Foundation

// The Xcode target imports these names from SentryDefines.h. SwiftPM's SentryHeaders
// module only forward-declares Event, so the importer drops the typedefs.
#if SWIFT_PACKAGE
/// Mutates an event before it is sent. Return `nil` to drop the event.
public typealias SentryBeforeSendEventCallback = (Event) -> Event?

/// Decides whether the SDK captures a screenshot for an event.
public typealias SentryBeforeCaptureScreenshotCallback = (Event) -> Bool

/// Decides whether the SDK captures a view hierarchy for an event.
public typealias SentryBeforeCaptureViewHierarchyCallback = (Event) -> Bool

#if !SDK_V10
/// Called when the previous process terminated with a crash.
public typealias SentryOnCrashedLastRunCallback = (Event) -> Void
#endif
#endif

private let sentryEventPlatformName = "cocoa"

/// An event sent to Sentry.
@objc(SentryEvent)
@objcMembers
open class Event: NSObject {

    /// Set by the initializer.
    public var eventId: SentryId

    /// Message of the event.
    public var message: SentryMessage?

    /// The error of the event.
    ///
    /// This property is a convenience for ``Options/beforeSend``. It is not serialized. While
    /// preparing the event, the client copies this error and any underlying errors into
    /// ``exceptions``.
    public var error: Error?

    /// When the event occurred.
    public var timestamp: Date?

    /// When the event started. Mostly useful for transactions.
    public var startTimestamp: Date?

    /// Severity of the event.
    public var level: SentryLevel

    /// Platform used for symbolication. Defaults to `cocoa`.
    public var platform: String

    /// Logger name.
    public var logger: String?

    /// Server name.
    public var serverName: String?

    /// Release name. Filled in before the event is sent.
    public var releaseName: String?

    /// Distribution. Filled in before the event is sent.
    public var dist: String?

    /// Environment used for this event.
    public var environment: String?

    /// Name of the transaction that caused this event.
    public var transaction: String?

    /// Event type, such as `transaction`.
    public var type: String?

    /// Arbitrary string tags shown with the event.
    ///
    /// For a ``Transaction`` read from `beforeSend`, this includes tracer tags.
    /// Tracer tags win. Swift subscript assignment calls the setter. Objective-C
    /// must assign the dictionary back onto the property.
    public var tags: [String: String]?

    /// Arbitrary additional information sent with the event.
    public var extra: [String: Any]?

    /// Information about the SDK. Maintained automatically.
    public var sdk: [String: Any]?

    /// Modules of the event.
    public var modules: [String: String]?

    /// Fingerprint used to group the event.
    public var fingerprint: [String]?

    /// User associated with the event.
    public var user: User?

    /// Meta information. Maintained automatically.
    public var context: [String: [String: Any]]?

    /// Threads captured for a crash or a user-reported exception.
    public var threads: [SentryThread]?

    /// Exceptions that led to the event, oldest first.
    public var exceptions: [Exception]?

    /// Stack trace sent with the event, in addition to threads.
    public var stacktrace: SentryStacktrace?

    /// Images loaded during runtime.
    public var debugMeta: [DebugMeta]?

    /// Breadcrumbs available when the event occurred.
    public var breadcrumbs: [Breadcrumb]?

    /// HTTP request information.
    public var request: SentryRequest?

    /// Whether this event is a fatal app termination, such as a crash, watchdog termination, or
    /// fatal app hang.
    @_spi(Private) @objc public var isFatalEvent = false

    /// Whether this event describes a previous process of the app.
    ///
    /// The client does not apply the current scope or the running process's state to such events.
    /// Fatal events are always from a previous process and are identified through ``isFatalEvent``.
    @_spi(Private) @objc public var isFromPreviousProcess = false

    /// Breadcrumbs already serialized to JSON, reused instead of turning dictionaries back into
    /// breadcrumbs only to serialize them again.
    @_spi(Private) @objc public var serializedBreadcrumbs: [Any]?

    /// Per-call override for `attachAllThreads`. When non-nil, overrides the value from options.
    @_spi(Private) @objc public var attachAllThreadsOverride: NSNumber?

#if !SDK_V10
    /// Whether this event represents an app hang.
    @_spi(Private) @objc public var isAppHangEvent: Bool {
        guard exceptions?.count == 1, let exceptionType = exceptions?.first?.type else {
            return false
        }
        return SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: exceptionType)
    }
#endif

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// System time when the profiled work started.
    @_spi(Private) @objc public var startSystemTime: UInt64 = 0

    /// System time when the profiled work ended.
    @_spi(Private) @objc public var endSystemTime: UInt64 = 0
#endif

    /// Creates an event and fills the default fields.
    @objc public required override init() {
        eventId = SentryId()
        level = .none
        platform = sentryEventPlatformName
        timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        super.init()
    }

    /// Creates an event at `level` and fills the default fields.
    @objc public init(level: SentryLevel) {
        eventId = SentryId()
        self.level = level
        platform = sentryEventPlatformName
        timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        super.init()
    }

    /// Creates an event for `error` at ``SentryLevel/error``.
    @objc public convenience init(error: Error) {
        self.init(level: .error)
        self.error = error
    }

#if SDK_V10
    /// Serializes the event into the Sentry payload dictionary.
    ///
    /// SPI keeps this out of the public snapshot. The method stays in the
    /// generated header so the Objective-C serializable category can see it,
    /// and `open` preserves overrides from outside this module.
    @_spi(Private) @objc open func serialize() -> [String: Any] {
        serializeEvent()
    }
#else
    /// Serializes the event into the Sentry payload dictionary.
    @objc open func serialize() -> [String: Any] {
        serializeEvent()
    }
#endif

    private func serializeEvent() -> [String: Any] {
        if timestamp == nil {
            timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        }

        var serializedData: [String: Any] = [
            "event_id": eventId.sentryIdString,
            "timestamp": timestamp?.timeIntervalSince1970 ?? 0,
            "platform": sentryEventPlatformName
        ]

        if level != .none {
            serializedData["level"] = SentryLevelHelper.nameForLevel(level)
        }

        addSimpleProperties(to: &serializedData)
        addOptionalListProperties(to: &serializedData)
        set("extra", sanitized(extra), on: &serializedData)
        set("tags", tags, on: &serializedData)

        SentrySDKLog.debug("Serialized event: \(serializedData)")
        return serializedData
    }

    private func addOptionalListProperties(to serializedData: inout [String: Any]) {
        let threadValues = serializedObjects(threads)
        if !threadValues.isEmpty {
            serializedData["threads"] = ["values": threadValues]
        }

        let exceptionValues = serializedObjects(exceptions)
        if !exceptionValues.isEmpty {
            serializedData["exception"] = ["values": exceptionValues]
        }

        let debugImages = serializedObjects(debugMeta)
        if !debugImages.isEmpty {
            serializedData["debug_meta"] = ["images": debugImages]
        }
    }

    private func addSimpleProperties(to serializedData: inout [String: Any]) {
        set("sdk", sanitized(sdk), on: &serializedData)
        set("release", releaseName, on: &serializedData)
        set("dist", dist, on: &serializedData)
        set("environment", environment, on: &serializedData)
        if let transaction {
            serializedData["transaction"] = transaction
        }
        set("fingerprint", fingerprint, on: &serializedData)
        set("user", serializedObject(user), on: &serializedData)
        set("modules", modules, on: &serializedData)
        set("stacktrace", serializedObject(stacktrace), on: &serializedData)
        addBreadcrumbs(to: &serializedData)
        set("contexts", sanitized(context), on: &serializedData)
        if let message {
            set("message", serializedObject(message), on: &serializedData)
        }
        set("logger", logger, on: &serializedData)
        set("server_name", serverName, on: &serializedData)
        set("type", type, on: &serializedData)
        addTransactionTimestamp(to: &serializedData)
        if let request {
            set("request", serializedObject(request), on: &serializedData)
        }
    }

    private func addBreadcrumbs(to serializedData: inout [String: Any]) {
        var crumbs = serializedObjects(breadcrumbs)
        if let serializedBreadcrumbs, !serializedBreadcrumbs.isEmpty {
            crumbs.append(contentsOf: serializedBreadcrumbs)
        }
        if !crumbs.isEmpty {
            serializedData["breadcrumbs"] = crumbs
        }
    }

    private func addTransactionTimestamp(to serializedData: inout [String: Any]) {
        guard type == "transaction", let timestamp else { return }
        serializedData["start_timestamp"] = (startTimestamp ?? timestamp).timeIntervalSince1970
    }
}

private func set<Value>(_ key: String, _ value: Value?, on data: inout [String: Any]) {
    if let value {
        data[key] = value
    }
}

#if !SDK_V10
extension Event: SentrySerializable {}
#endif

extension Scope {
    @discardableResult
    func applyTo(event: Event?, maxBreadcrumbs: UInt) -> Event? {
        applyToMigration(event: event, maxBreadcrumbs: maxBreadcrumbs) as? Event
    }
}

private func serializedObject(_ object: AnyObject?) -> Any? {
    (object as? SentryInternalSerializable)?.serialize()
}

private func serializedObjects(_ objects: [AnyObject]?) -> [Any] {
    objects?.compactMap { serializedObject($0) } ?? []
}

private func sanitized(_ dictionary: [String: Any]?) -> Any? {
    sentry_sanitize_dictionary(dictionary as NSDictionary?)
}

private func sanitized(_ dictionary: [String: [String: Any]]?) -> Any? {
    sentry_sanitize_dictionary(dictionary as NSDictionary?)
}
