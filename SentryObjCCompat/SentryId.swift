internal import SentrySwift
import Foundation

/// 32-character hexadecimal identifier for a Sentry event.
///
/// Mirrors `Sentry.SentryId` without exposing it on the wrapper's public ABI.
@objc(SOCSentryId)
public final class SentryId: NSObject {
    internal let wrapped: SentrySwift.SentryId

    internal init(_ wrapped: SentrySwift.SentryId) {
        self.wrapped = wrapped
        super.init()
    }

    /// Creates an id with a random UUID.
    @objc public override init() {
        self.wrapped = SentrySwift.SentryId()
        super.init()
    }

    /// Creates an id from an existing UUID.
    @objc public init(uuid: UUID) {
        self.wrapped = SentrySwift.SentryId(uuid: uuid)
        super.init()
    }

    /// Creates an id from a 32- or 36-character hex string. Returns
    /// `SentryId.empty` for invalid input, matching the underlying SDK.
    @objc public init(uuidString: String) {
        self.wrapped = SentrySwift.SentryId(uuidString: uuidString)
        super.init()
    }

    /// Lower-case 32-character hexadecimal string.
    @objc public var sentryIdString: String {
        wrapped.sentryIdString
    }

    /// An id whose UUID is all zeros.
    @objc public static var empty: SentryId {
        SentryId(SentrySwift.SentryId.empty)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SentryId else { return false }
        return wrapped.isEqual(other.wrapped)
    }

    public override var hash: Int {
        wrapped.hash
    }

    public override var description: String {
        wrapped.sentryIdString
    }
}
