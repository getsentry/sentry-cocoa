/// Provides metadata about the origin of an event or breadcrumb.
///
/// A hint flows alongside the event through the capture pipeline, giving ``Options/beforeSendWithHint``
/// and ``Options/beforeBreadcrumbWithHint`` callbacks access to the raw source material that produced
/// the event — such as the original `NSError` or `NSException` — and the list of attachments that will
/// be sent with it.
///
/// ## Thread Safety
/// All property access is guarded by a lock. It is safe to read and write from any queue.
@objc(SentryHint)
@objcMembers
public final class Hint: NSObject {

    private let lock = NSLock()

    private var _originalError: Error?
    private var _originalException: NSException?
    private var _attachments: [Attachment]
    private var _extra: [String: Any]

    /// The original `Error` (typically an `NSError`) that triggered the event capture, if any.
    public var originalError: Error? {
        get { lock.withLock { _originalError } }
        set { lock.withLock { _originalError = newValue } }
    }

    /// The original `NSException` that triggered the event capture, if any.
    public var originalException: NSException? {
        get { lock.withLock { _originalException } }
        set { lock.withLock { _originalException = newValue } }
    }

    /// The attachments that will be sent alongside the event.
    ///
    /// Add attachments in ``Options/beforeSendWithHint`` to include them with the event.
    /// These are merged with scope attachments after the callback returns.
    public var attachments: [Attachment] {
        get { lock.withLock { _attachments } }
        set { lock.withLock { _attachments = newValue } }
    }

    public override init() {
        _originalError = nil
        _originalException = nil
        _attachments = []
        _extra = [:]
        super.init()
    }

    /// Creates a hint pre-populated with the original error.
    @objc public convenience init(error: Error) {
        self.init()
        _originalError = error
    }

    /// Creates a hint pre-populated with the original exception.
    @objc public convenience init(exception: NSException) {
        self.init()
        _originalException = exception
    }

    // MARK: - Generic Key-Value Storage

    /// Stores an arbitrary value in the hint, accessible by key.
    @objc
    public func setHintValue(_ value: Any, forKey key: String) {
        lock.withLock { _extra[key] = value }
    }

    /// Returns the value associated with the given key, or `nil` if not set.
    @objc
    public func hintValue(forKey key: String) -> Any? {
        lock.withLock { _extra[key] }
    }

    /// Removes the value for the given key.
    @objc
    public func removeHintValue(forKey key: String) {
        lock.withLock { _ = _extra.removeValue(forKey: key) }
    }
}
