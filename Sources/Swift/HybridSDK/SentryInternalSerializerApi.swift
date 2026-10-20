// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

/// Serialization APIs for Sentry hybrid SDKs.
public struct SentryInternalSerializerApi {

    /// Returns a scope's dictionary, including the singular `context` key used by hybrid SDKs.
    public func serialize(scope: Scope) -> [String: Any] {
        scope.serialize()
    }

    /// Returns a debug image's Sentry wire-format dictionary.
    public func serialize(debugMeta: DebugMeta) -> [String: Any] {
        debugMeta.serialize()
    }

    /// Returns an event's Sentry wire-format dictionary.
    public func serialize(event: Event) -> [String: Any] {
        event.serialize()
    }
}
// swiftlint:enable missing_docs
