@_implementationOnly import Sentry
import Foundation

/// 16-character span identifier.
@objc(SOCSentrySpanId)
public final class SpanId: NSObject {
    internal let wrapped: Sentry.SpanId

    internal init(_ wrapped: Sentry.SpanId) {
        self.wrapped = wrapped
        super.init()
    }

    /// Creates a span id with a random 16-character value.
    @objc public override init() {
        self.wrapped = Sentry.SpanId()
        super.init()
    }

    /// Creates a span id from the first 16 characters of a UUID.
    @objc public init(uuid: UUID) {
        self.wrapped = Sentry.SpanId(uuid: uuid)
        super.init()
    }

    /// Creates a span id from a 16-character string. Falls back to `empty`
    /// for invalid input, matching the SDK.
    @objc public init(value: String) {
        self.wrapped = Sentry.SpanId(value: value)
        super.init()
    }

    @objc public var sentrySpanIdString: String { wrapped.sentrySpanIdString }

    @objc public static var empty: SpanId { SpanId(Sentry.SpanId.empty) }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SpanId else { return false }
        return wrapped.isEqual(other.wrapped)
    }

    public override var hash: Int { wrapped.hash }
    public override var description: String { wrapped.sentrySpanIdString }
}
