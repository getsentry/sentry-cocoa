// swiftlint:disable missing_docs
@_spi(Private) internal import _SentryPrivate
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

    /// Captures an envelope whose unhandled exceptions did not terminate the process.
    ///
    /// Use this instead of ``capture(_:)`` in runtimes such as Flutter, where the framework keeps the
    /// process alive after an unhandled exception. The current session keeps running with the same ID
    /// and only its error count increases, but it ends with the `unhandled` status instead of
    /// `exited`. A later crash or abnormal exit still takes precedence over `unhandled`.
    @_spi(Private) public func captureNonTerminating(_ envelope: SentryEnvelope) {
        hub.captureNonTerminatingEnvelope(envelope)
    }

    /// Deserializes an envelope from raw data.
    @_spi(Private) public func deserialize(from data: Data) -> SentryEnvelope? {
        SentrySerializationSwift.envelope(with: data)
    }
}
// swiftlint:enable missing_docs
