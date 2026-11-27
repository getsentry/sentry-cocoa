// swiftlint:disable missing_docs
import Foundation

@objcMembers
public final class SentryViewScreenshotOptions: NSObject {
    /**
     * Default values for the screenshot options.
     *
     * - Note: These values are used to ensure the different initializers use the same default values.
     */
    public final class DefaultValues {
        public static let enableViewRendererV2: Bool = true
        public static let enableFastViewRendering: Bool = false
        
    }
    
    // MARK: - Rendering
    
    /**
     * Enables the up to 5x faster new view renderer.
     *
     * Enabling this flag will reduce the amount of time it takes to render the screenshot on the main thread, therefore reducing
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * **up to 4-5x faster rendering** (reducing `~160ms` to `~36ms`) on older devices.
     *
     * - Experiment: In case you are noticing issues with the new view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa).
     *               Eventually, we will remove this feature flag and use the new view renderer by default.
     *
     * - Note: See ``SentryViewScreenshotOptions.init`` for the default value.
     */
    public var enableViewRendererV2: Bool
    
    /**
     * Enables up to 5x faster but incomplete view rendering.
     *
     * Enabling this flag will reduce the amount of time it takes to render the screenshot, therefore reducing
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * up to **5x faster render times** (reducing `~160ms` to `~30ms`) on older devices.
     *
     * This flag controls the way the view hierarchy is drawn into a graphics context. By default, the view hierarchy is drawn using
     * the `UIView.drawHierarchy(in:afterScreenUpdates:)` method, which is the most complete way to render the view hierarchy. However,
     * this method can be slow, especially when rendering complex views, therefore enabling this flag will switch to render the underlying `CALayer` instead.
     *
     * - Note: This flag can only be used together with `enableViewRendererV2` with up to 20% faster render times.
     * - Warning: Rendering the view hierarchy using the `CALayer.render(in:)` method can lead to rendering issues, especially when using custom views.
     *            For complete rendering, it is recommended to set this option to `false`. In case you prefer performance over completeness, you can
     *            set this option to `true`.
     * - Experiment: This is an experimental feature and is therefore disabled by default. In case you are noticing issues with the experimental
     *               view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa). Eventually, we will
     *               mark this feature as stable and remove the experimental flag, but will keep it disabled by default.
     *
     * - Note: See ``SentryViewScreenshotOptions.init`` for the default value.
     */
    public var enableFastViewRendering: Bool
    
    /// Initializes screenshot rendering options.
    public convenience override init() {
        self.init(enableViewRendererV2: DefaultValues.enableViewRendererV2,
                  enableFastViewRendering: DefaultValues.enableFastViewRendering)
    }

    convenience init(dictionary: [String: Any]) {
        self.init(
            enableViewRendererV2: (dictionary["enableViewRendererV2"] as? NSNumber)?.boolValue ?? DefaultValues.enableViewRendererV2,
            enableFastViewRendering: (dictionary["enableFastViewRendering"] as? NSNumber)?.boolValue ?? DefaultValues.enableFastViewRendering
        )
    }

    /// Initializes screenshot rendering options.
    /// - Parameters:
    ///   - enableViewRendererV2: Enables the faster view renderer.
    ///   - enableFastViewRendering: Enables faster but incomplete view rendering.
    public init(
        enableViewRendererV2: Bool = DefaultValues.enableViewRendererV2,
        enableFastViewRendering: Bool = DefaultValues.enableFastViewRendering
    ) {
        self.enableViewRendererV2 = enableViewRendererV2
        self.enableFastViewRendering = enableFastViewRendering
        super.init()
    }

}

// swiftlint:enable missing_docs
