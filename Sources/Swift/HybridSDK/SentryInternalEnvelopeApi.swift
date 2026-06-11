@_implementationOnly import _SentryPrivate
import Foundation

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalEnvelopeApi {

    /// Stores an envelope synchronously to disk.
    public func store(_ envelope: SentryEnvelope) {
        SentrySDKInternal.currentHub().perform(
            NSSelectorFromString("storeEnvelope:"), with: envelope
        )
    }

    /// Captures an envelope, sending it to Sentry.
    public func capture(_ envelope: SentryEnvelope) {
        SentrySDKInternal.currentHub().perform(
            NSSelectorFromString("captureEnvelope:"), with: envelope
        )
    }

    /// Deserializes an envelope from raw data.
    /// - Returns: The deserialized envelope, or `nil` if the data is invalid.
    public func deserialize(from data: Data) -> SentryEnvelope? {
        SentrySerializationSwift.envelope(with: data)
    }
}
