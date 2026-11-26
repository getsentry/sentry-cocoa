// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

// Objective-C scope/span internals need to own and serialize feature flag buffers, but
// SentryFeatureFlagBuffer is a pure Swift type. Keep this wrapper thin: ObjC gets only the
// serialization/copying methods it needs, while Swift uses typed wrapper methods.
@_spi(Private)
@objc(SentryFeatureFlagBufferWrapper)
public final class SentryFeatureFlagBufferWrapper: NSObject {
    private let buffer: SentryFeatureFlagBuffer

    private init(buffer: SentryFeatureFlagBuffer) {
        self.buffer = buffer
        super.init()
    }

    @objc
    public static func scopeBuffer() -> SentryFeatureFlagBufferWrapper {
        scopeBuffer(maxSize: defaultMaxScopeFeatureFlags)
    }

    /// Creates a scope buffer retaining at most `maxSize` unique evaluations.
    /// `SentryScope` passes `Options.maxFeatureFlags` here.
    @objc
    public static func scopeBuffer(maxSize: Int) -> SentryFeatureFlagBufferWrapper {
        SentryFeatureFlagBufferWrapper(buffer: SentryFeatureFlagBuffer.scopeBuffer(maxSize: maxSize))
    }

    @objc
    public static func spanBuffer() -> SentryFeatureFlagBufferWrapper {
        SentryFeatureFlagBufferWrapper(buffer: SentryFeatureFlagBuffer.spanBuffer())
    }

    @objc
    public func add(name: String, result: Bool) {
        buffer.add(name: name, value: result)
    }

    @objc
    public func removeAll() {
        buffer.removeAll()
    }

    @objc
    public func copyBuffer() -> SentryFeatureFlagBufferWrapper {
        SentryFeatureFlagBufferWrapper(buffer: buffer.copy())
    }

    @objc
    public func serializeForContext() -> [String: Any]? {
        buffer.serializeForContext()
    }

    @objc
    public func serializeForSpanData() -> [String: Any] {
        buffer.serializeForSpanData()
    }
}
// swiftlint:enable missing_docs
