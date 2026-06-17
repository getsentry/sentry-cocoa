// swiftlint:disable missing_docs
@_spi(Private) @_implementationOnly import _SentryPrivate
import Foundation

/// Provides envelope operations for hybrid SDKs.
public struct SentryInternalEnvelopeApi {

    typealias Dependencies = HubProvider

    private let hub: Hub

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
    }

    /// Synchronously stores an envelope to disk.
    @_spi(Private) public func store(_ envelope: SentryEnvelope) {
        hub.storeEnvelope(envelope)
    }

    /// Captures an envelope and sends it to Sentry.
    @_spi(Private) public func capture(_ envelope: SentryEnvelope) {
        hub.captureEnvelope(envelope)
    }

    /// Deserializes an envelope from raw data.
    @_spi(Private) public func deserialize(from data: Data) -> SentryEnvelope? {
        SentrySerializationSwift.envelope(with: data)
    }
}
// swiftlint:enable missing_docs
