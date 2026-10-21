internal import _SentryPrivate
import Foundation

/// An event that can be sent to Sentry.
@objc(SentryEvent)
open class Event: NSObject {
    private static let platformName = "cocoa"

    /// This will be set by the initializer.
    @objc open var eventId = SentryId()

    /// Message of the event.
    @objc open var message: SentryMessage?

    /// The error of the event. This property adds convenience to access the error directly in
    /// `beforeSend`. This property is not serialized. Instead, when preparing the event, the
    /// client puts the error and any underlying errors into exceptions.
    @objc open var error: Error?

    /// Date when the event occurred.
    @objc open var timestamp: Date?

    /// Date when the event started, mostly useful if the event type is a transaction.
    @objc open var startTimestamp: Date?

    /// Level of the event.
    @objc open var level = SentryLevel.none

    /// This will be used for symbolicating on the server and should be "cocoa".
    @objc open var platform = Event.platformName

    /// The logger name.
    @objc open var logger: String?

    /// The server name.
    @objc open var serverName: String?

    /// Filled before the event is sent. Maintained automatically.
    @objc open var releaseName: String?

    /// Filled before the event is sent. Maintained automatically.
    @objc open var dist: String?

    /// The environment used for this event.
    @objc open var environment: String?

    /// The name of the transaction which caused this event.
    @objc open var transaction: String?

    /// The type of the event: null, default, or transaction.
    @objc open var type: String?

    /// Arbitrary key-value data shown with the event.
    ///
    /// For `Transaction` instances accessed in `beforeSend`, this property returns a merged
    /// dictionary of event tags and tracer tags, with tracer tags taking precedence.
    /// Modifications persist when using Swift subscript assignment, which calls the setter.
    /// In Objective-C, call the setter after modifying the dictionary.
    @objc open var tags: [String: String]?

    /// Arbitrary additional information sent with the event.
    @objc open var extra: [String: Any]?

    /// Information about the SDK. Maintained automatically.
    @objc open var sdk: [String: Any]?

    /// Modules of the event.
    @objc open var modules: [String: String]?

    /// Fingerprint used to determine event grouping.
    @objc open var fingerprint: [String]?

    /// User for the event.
    @objc open var user: User?

    /// Meta information. Maintained automatically.
    ///
    /// Objective-C can store values that are not dictionaries. Those values stay on the event
    /// for Objective-C readers and for serialization. Swift reads only dictionary values.
    open var context: [String: [String: Any]]? {
        get { Self.swiftContext(contextStorage) }
        set { contextStorage = newValue as NSDictionary? }
    }

    private var contextStorage: NSDictionary?

    /// Objective-C accessor. The Swift property would trap when a stored value is not a dictionary.
    @objc(context)
    @available(swift, obsoleted: 1.0, renamed: "context")
    open func objcContext() -> NSDictionary? {
        contextStorage
    }

    /// Objective-C setter. Keeps the assigned dictionary, including non-dictionary values.
    @objc(setContext:)
    @available(swift, obsoleted: 1.0, renamed: "context")
    open func objcSetContext(_ context: NSDictionary?) {
        contextStorage = context
    }

    /// Threads included when a crash occurred or for a user reported exception.
    @objc open var threads: [SentryThread]?

    /// Exceptions encountered, starting with the oldest at the beginning of the array.
    @objc open var exceptions: [Exception]?

    /// A stacktrace that can be sent with the event, besides threads.
    @objc open var stacktrace: SentryStacktrace?

    /// Images loaded during runtime.
    @objc open var debugMeta: [DebugMeta]?

    /// Breadcrumbs available when the event occurred or will be sent.
    @objc open var breadcrumbs: [Breadcrumb]?

    /// HTTP request information.
    @objc open var request: SentryRequest?

    /// Indicates whether this event is a fatal app termination, such as a crash, watchdog
    /// termination, or a fatal app hang.
    @_spi(Private) @objc public var isFatalEvent = false

    /// Indicates whether this event describes something that happened in a previous process, such
    /// as a MetricKit diagnostic delivered on a later launch. The client does not apply the
    /// current scope or the running process's state to these events. Fatal events are always from
    /// a previous process and are identified through `isFatalEvent` instead.
    @_spi(Private) @objc public var isFromPreviousProcess = false

#if !SDK_V10
    /// Indicates whether this event represents an app hang.
    @_spi(Private) @objc public var isAppHangEvent: Bool {
        guard let exceptions, exceptions.count == 1, let exceptionType = exceptions.first?.type else {
            return false
        }
        return SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: exceptionType)
    }
#endif // !SDK_V10

    /// Pre-serialized breadcrumbs stored for watchdog termination so they are not decoded and
    /// encoded again.
    @_spi(Private) @objc public var serializedBreadcrumbs: [Any]?

    /// Per-call override for `attachAllThreads`. When non-nil, overrides the value from options.
    @_spi(Private) @objc public var attachAllThreadsOverride: NSNumber?

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// System time when the profiled transaction started.
    @_spi(Private) @objc public var startSystemTime: UInt64 = 0

    /// System time when the profiled transaction ended.
    @_spi(Private) @objc public var endSystemTime: UInt64 = 0
#endif // !(os(watchOS) || os(tvOS) || os(visionOS))

    /// Creates an event and sets the default fields.
    @objc public required override init() {
        super.init()
        configure(level: SentryLevel.none)
    }

    /// Creates an event with the given level and sets the default fields.
    @objc public init(level: SentryLevel) {
        super.init()
        configure(level: level)
    }

    /// Creates an event for an error and sets the level to `SentryLevel.error`.
    @objc public convenience init(error: Error) {
        self.init(level: SentryLevel.error)
        self.error = error
    }

    private func configure(level: SentryLevel) {
        eventId = SentryId()
        self.level = level
        platform = Event.platformName
        timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
    }

    /// Serializes the event into the payload sent to Sentry.
    /// In V10 this stays SDK-private, matching the internal serializable protocol.
#if SDK_V10
    @_spi(Private)
#endif
    @objc open func serialize() -> [String: Any] {
        if timestamp == nil {
            timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
        }

        var serializedData: [String: Any] = [
            "event_id": eventId.sentryIdString,
            "timestamp": timestamp?.timeIntervalSince1970 ?? 0,
            "platform": Event.platformName
        ]

        if level != SentryLevel.none {
            serializedData["level"] = SentryLevelHelper.nameForLevel(level)
        }

        addSimpleProperties(to: &serializedData)
        addOptionalListProperties(to: &serializedData)

        set(sentry_sanitize_dictionary(extra as NSDictionary?), for: "extra", in: &serializedData)
        set(tags, for: "tags", in: &serializedData)
        SentrySDKLog.debug("Serialized event: \(serializedData)")

        return serializedData
    }

    private func addOptionalListProperties(to serializedData: inout [String: Any]) {
        if let threads, !threads.isEmpty {
            serializedData["threads"] = ["values": threads.map { $0.serialize() }] as NSDictionary
        }
        if let exceptions, !exceptions.isEmpty {
            serializedData["exception"] = ["values": exceptions.map { $0.serialize() }] as NSDictionary
        }
        if let debugMeta, !debugMeta.isEmpty {
            serializedData["debug_meta"] = ["images": debugMeta.map { $0.serialize() }] as NSDictionary
        }
    }

    private func addSimpleProperties(to serializedData: inout [String: Any]) {
        set(sentry_sanitize_dictionary(sdk as NSDictionary?), for: "sdk", in: &serializedData)
        set(releaseName, for: "release", in: &serializedData)
        set(dist, for: "dist", in: &serializedData)
        set(environment, for: "environment", in: &serializedData)
        set(transaction, for: "transaction", in: &serializedData)
        set(fingerprint, for: "fingerprint", in: &serializedData)
        set(user?.serialize() as NSDictionary?, for: "user", in: &serializedData)
        set(modules, for: "modules", in: &serializedData)
        set(stacktrace?.serialize() as NSDictionary?, for: "stacktrace", in: &serializedData)

        var breadcrumbs: [Any] = (self.breadcrumbs ?? []).map { $0.serialize() as NSDictionary }
        if let serializedBreadcrumbs, !serializedBreadcrumbs.isEmpty {
            breadcrumbs.append(contentsOf: serializedBreadcrumbs)
        }
        if !breadcrumbs.isEmpty {
            serializedData["breadcrumbs"] = breadcrumbs as NSArray
        }

        set(
            sentry_sanitize_dictionary(contextStorage),
            for: "contexts",
            in: &serializedData
        )
        set(message?.serialize() as NSDictionary?, for: "message", in: &serializedData)
        set(logger, for: "logger", in: &serializedData)
        set(serverName, for: "server_name", in: &serializedData)
        set(type, for: "type", in: &serializedData)

        if type == "transaction" {
            let start = startTimestamp ?? timestamp
            set(start?.timeIntervalSince1970, for: "start_timestamp", in: &serializedData)
        }

        set(request?.serialize(), for: "request", in: &serializedData)
    }

    private func set(_ value: Any?, for key: String, in serializedData: inout [String: Any]) {
        guard let value else { return }
        serializedData[key] = value
    }

    private static func swiftContext(_ storage: NSDictionary?) -> [String: [String: Any]]? {
        guard let storage else { return nil }
        var result: [String: [String: Any]] = [:]
        result.reserveCapacity(storage.count)
        for case let (key as String, value) in storage {
            if let nested = value as? [String: Any] {
                result[key] = nested
            } else if let nested = value as? NSDictionary {
                var converted: [String: Any] = [:]
                converted.reserveCapacity(nested.count)
                for case let (nestedKey as String, nestedValue) in nested {
                    converted[nestedKey] = nestedValue
                }
                result[key] = converted
            }
        }
        return result
    }
}

#if !SDK_V10
extension Event: SentrySerializable {}
#endif // !SDK_V10

/// Mutates an event before it is sent. Return `nil` to drop the event.
public typealias BeforeSendEventCallback = (Event) -> Event?

/// Decides whether the SDK should capture a screenshot. Return `false` to skip the screenshot.
/// This callback is not invoked for crashes.
public typealias BeforeCaptureScreenshotCallback = (Event) -> Bool

/// Decides whether the SDK should capture a view hierarchy. Return `false` to skip it.
/// This callback is not invoked for crashes.
public typealias BeforeCaptureViewHierarchyCallback = (Event) -> Bool

#if !SDK_V10
/// Called when the previous process execution terminated with a crash.
public typealias OnCrashedLastRunCallback = (Event) -> Void
#endif // !SDK_V10

/// Deprecated. Use ``BeforeSendEventCallback``.
@available(*, deprecated, renamed: "BeforeSendEventCallback")
public typealias SentryBeforeSendEventCallback = BeforeSendEventCallback

/// Deprecated. Use ``BeforeCaptureScreenshotCallback``.
@available(*, deprecated, renamed: "BeforeCaptureScreenshotCallback")
public typealias SentryBeforeCaptureScreenshotCallback = BeforeCaptureScreenshotCallback

/// Deprecated. Use ``BeforeCaptureViewHierarchyCallback``.
@available(*, deprecated, renamed: "BeforeCaptureViewHierarchyCallback")
public typealias SentryBeforeCaptureViewHierarchyCallback = BeforeCaptureViewHierarchyCallback

#if !SDK_V10
/// Deprecated. Use ``OnCrashedLastRunCallback``.
@available(*, deprecated, renamed: "OnCrashedLastRunCallback")
public typealias SentryOnCrashedLastRunCallback = OnCrashedLastRunCallback
#endif // !SDK_V10
