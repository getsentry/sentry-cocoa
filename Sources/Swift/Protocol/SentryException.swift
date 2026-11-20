internal import _SentryPrivate
import Foundation

/// A single exception in a Sentry event.
@objc(SentryException)
@objcMembers
open class Exception: NSObject {

    /// The name of the exception.
    public var value: String?

    /// Type of the exception.
    public var type: String?

    /// Additional information about the exception.
    public var mechanism: Mechanism?

    /// Can be set to define the module.
    public var module: String?

    /// An optional value which refers to a thread in an event's threads.
    public var threadId: NSNumber?

    /// Stacktrace containing frames of this exception.
    public var stacktrace: SentryStacktrace?

    /// Creates an exception with a value and a type.
    ///
    /// At least one of value or type must be non-nil. This is asserted in debug builds.
    @objc public init(value: String?, type: String?) {
        assert(
            value != nil || type != nil,
            "SentryException requires at least one of value or type to be non-nil"
        )
        super.init()
        self.value = value
        self.type = type
    }

    /// Unavailable. Exceptions are created with a value, a type, or both.
    ///
    /// `public` is required because this class is `open`. `@nonobjc` keeps
    /// `@objcMembers` from publishing the initializer.
    @nonobjc
    @available(*, unavailable)
    public required override init() {
        fatalError("init() is unavailable")
    }

#if SDK_V10
    /// Serializes the exception into the Sentry payload dictionary.
    ///
    /// SPI keeps this out of the public snapshot. The method stays in the
    /// generated header so the Objective-C serializable category can see it,
    /// and `open` preserves overrides from outside this module.
    @_spi(Private) @objc open func serialize() -> [String: Any] {
        serializeException()
    }
#else
    /// Serializes the exception into the Sentry payload dictionary.
    @objc open func serialize() -> [String: Any] {
        serializeException()
    }
#endif

    private func serializeException() -> [String: Any] {
        var serializedData: [String: Any] = [:]
        set("value", value, on: &serializedData)
        set("type", type, on: &serializedData)
        set("mechanism", serializedObject(mechanism), on: &serializedData)
        set("module", module, on: &serializedData)
        set("thread_id", threadId, on: &serializedData)
        set("stacktrace", serializedObject(stacktrace), on: &serializedData)
        return serializedData
    }
}

#if !SDK_V10
extension Exception: SentrySerializable {}
#endif

private func set(_ key: String, _ value: Any?, on data: inout [String: Any]) {
    if let value {
        data[key] = value
    }
}

private func serializedObject(_ object: AnyObject?) -> Any? {
    (object as? SentryInternalSerializable)?.serialize()
}
