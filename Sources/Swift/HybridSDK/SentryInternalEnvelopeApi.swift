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
    /// process alive after an unhandled exception. Applies the same session side effects as
    /// ``updateSessionForDroppedEventNonTerminating(unhandled:)``, then sends the envelope with the
    /// still-running session attached as an intermediate update. The current session keeps running
    /// with the same ID and only its error count increases, but it ends with the `unhandled` status
    /// instead of `exited`. A later crash or abnormal exit still takes precedence over `unhandled`.
    ///
    /// Do not also call ``updateSessionForDroppedEventNonTerminating(unhandled:)`` for the same
    /// event; that would double-count. Use that method only when the error is dropped by sampling
    /// and no envelope is sent.
    @_spi(Private) public func captureNonTerminating(_ envelope: SentryEnvelope) {
        hub.captureNonTerminatingEnvelope(envelope)
    }

    /// Session side effects of ``captureNonTerminating(_:)`` without sending the event.
    ///
    /// Hybrid SDKs should call this when an error is dropped by sampling.
    /// Do not call this for events dropped by `beforeSend` or ignored exception types, and do not
    /// call it in addition to ``captureNonTerminating(_:)`` for the same event.
    ///
    /// - Parameter unhandled: `true` if the dropped error was unhandled (`mechanism.handled=false`).
    @_spi(Private) public func updateSessionForDroppedEventNonTerminating(unhandled: Bool) {
        hub.updateSessionForDroppedEventNonTerminating(unhandled: unhandled)
    }

    /// Deserializes an envelope from raw data.
    @_spi(Private) public func deserialize(from data: Data) -> SentryEnvelope? {
        SentrySerializationSwift.envelope(with: data)
    }
}
// swiftlint:enable missing_docs
