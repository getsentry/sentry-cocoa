// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

/// Lightweight transport abstraction used by the telemetry processor to send envelopes.
/// Exists because using the Objective-C `SentryTransport` adapter directly from Swift pulls in many ObjC dependencies
/// and caused build/compile issues; we only need envelope sending here, so this protocol keeps it minimal.
@objc @_spi(Private) public protocol SentryTelemetryProcessorTransport {
    func sendEnvelope(envelope: SentryEnvelope)
}

// swiftlint:enable missing_docs
