// swiftlint:disable missing_docs
import Foundation

/// Serialization APIs for Sentry hybrid SDKs.
public struct SentryInternalSerializerApi {

    /// Returns an event's Sentry wire-format dictionary.
    public func serialize(event: Event) -> [String: Any] {
        event.serialize()
    }
}
// swiftlint:enable missing_docs
