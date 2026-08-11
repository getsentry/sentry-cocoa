import Foundation

/// Configuration for a tracer.
@_spi(Private)
@objc(SentryTracerConfiguration)
public final class SentryTracerConfiguration: NSObject {
    /// Returns an instance with default values.
    @objc(defaultConfiguration) public static var `default`: SentryTracerConfiguration {
        SentryTracerConfiguration()
    }

    @objc public override init() {
        super.init()
    }

    /// Indicates whether the tracer finishes only after all child spans finish.
    /// Defaults to `false`.
    @objc public var waitForChildren = false

    /// Indicates whether an explicit call to finish is required.
    /// Defaults to `false`.
    @objc public var finishMustBeCalled = false

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Whether a profile is sampled for this trace.
    @objc public var profilesSamplerDecision: SentrySamplerDecision?
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    /// The idle timeout in seconds before the transaction finishes.
    /// Defaults to `0`.
    @objc public var idleTimeout: TimeInterval = 0

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// The app start measurement to attach to this tracer.
    @objc public var appStartMeasurement: SentryAppStartMeasurement?
#endif // SENTRY_HAS_UIKIT

    /// Creates a configuration and applies the given block.
    public convenience init(block: (SentryTracerConfiguration) -> Void) {
        self.init()
        block(self)
    }

    /// Creates a configuration and applies the given block.
    @objc(configurationWithBlock:)
    public class func configuration(with block: @escaping (SentryTracerConfiguration) -> Void) -> SentryTracerConfiguration {
        SentryTracerConfiguration(block: block)
    }
}
