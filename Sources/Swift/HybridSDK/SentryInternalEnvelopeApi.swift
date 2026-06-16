// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Provides envelope operations for hybrid SDKs.
public struct SentryInternalEnvelopeApi {

    init() {}

    /// Synchronously stores an envelope to disk.
    @_spi(Private)
    public func store(_ envelope: SentryEnvelope) {
        SentrySDKInternal.store(envelope)
    }

    /// Captures an envelope and sends it to Sentry.
    @_spi(Private)
    public func capture(_ envelope: SentryEnvelope) {
        SentrySDKInternal.capture(envelope)
    }

    /// Deserializes an envelope from raw data.
    @_spi(Private)
    public func deserialize(from data: Data) -> SentryEnvelope? {
        SentrySerializationSwift.envelope(with: data)
    }
}
// swiftlint:enable missing_docs
