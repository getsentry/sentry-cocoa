/// Provides metadata about the origin of an event or breadcrumb.
///
/// A hint flows alongside the event through the capture pipeline, giving ``Options/beforeSendWithHint``
/// and ``Options/beforeBreadcrumbWithHint`` callbacks access to the raw source material that produced
/// the event — such as the original `NSError` or `NSException` — and the list of attachments that will
/// be sent with it.
///
/// ## Thread Safety
/// All property access is guarded by a mutex. It is safe to read and write from any queue.
@objc(SentryHint)
@objcMembers
public final class Hint: NSObject {

    private struct State {
        var originalError: Error?
        var originalException: NSException?
        var attachments: [Attachment] = []
        var extra: [String: Any] = [:]
    }

    private let state = SentryMutex(State())

    /// The original `Error` (typically an `NSError`) that triggered the event capture, if any.
    public var originalError: Error? {
        get { state.withLock { $0.originalError } }
        set { state.withLock { $0.originalError = newValue } }
    }

    /// The original `NSException` that triggered the event capture, if any.
    public var originalException: NSException? {
        get { state.withLock { $0.originalException } }
        set { state.withLock { $0.originalException = newValue } }
    }

    /// The attachments that will be sent alongside the event.
    ///
    /// Before ``Options/beforeSendWithHint`` is invoked, the SDK pre-populates this list with the
    /// attachments that will be sent with the event, such as the scope's attachments. The list left
    /// in the hint when the callback returns is what the SDK sends, so attachments can be both
    /// added and removed in the callback.
    public var attachments: [Attachment] {
        get { state.withLock { $0.attachments } }
        set { state.withLock { $0.attachments = newValue } }
    }

    public override init() {
        super.init()
    }

    /// Creates a hint pre-populated with the original error.
    @objc public convenience init(error: Error) {
        self.init()
        state.withLock { $0.originalError = error }
    }

    /// Creates a hint pre-populated with the original exception.
    @objc public convenience init(exception: NSException) {
        self.init()
        state.withLock { $0.originalException = exception }
    }

    // MARK: - Generic Key-Value Storage

    /// Stores an arbitrary value in the hint, accessible by key.
    @objc
    public func setHintValue(_ value: Any, forKey key: String) {
        state.withLock { $0.extra[key] = value }
    }

    /// Returns the value associated with the given key, or `nil` if not set.
    @objc
    public func hintValue(forKey key: String) -> Any? {
        state.withLock { $0.extra[key] }
    }

    /// Removes the value for the given key.
    @objc
    public func removeHintValue(forKey key: String) {
        state.withLock { _ = $0.extra.removeValue(forKey: key) }
    }
}
