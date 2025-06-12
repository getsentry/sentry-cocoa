import Foundation

@objcMembers
public class SentryScreenshotOptions: NSObject, SentryRedactOptions {
    /**
     * Default values for the screenshot options.
     *
     * - Note: These values are used to ensure the different initializers use the same default values.
     */
    public class DefaultValues {
        public static let enableViewRendererV2: Bool = true
        public static let enableFastViewRendering: Bool = false

        public static let maskAllText: Bool = true
        public static let maskAllImages: Bool = true
        public static let maskedViewClasses: [AnyClass] = []
        public static let unmaskedViewClasses: [AnyClass] = []
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
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var enableViewRendererV2: Bool

    /**
     * Enables up to 5x faster but incomplete view rendering.
     *
     * Enabling this flag will reduce the amount of time it takes to render the screenshot, therefore reducing
     * interruptions and visual lag. [Our benchmarks](https://github.com/getsentry/sentry-cocoa/pull/4940) have shown a significant improvement of
     * up to **5x faster render times** (reducing `~160ms` to `~30ms`) on older devices.
     *
     * This flag controls the way the view hierarchy is drawn into a graphics context for the session replay. By default, the view hierarchy is drawn using
     * the `UIView.drawHierarchy(in:afterScreenUpdates:)` method, which is the most complete way to render the view hierarchy. However,
     * this method can be slow, especially when rendering complex views, therefore enabling this flag will switch to render the underlying `CALayer` instead.
     *
     * - Note: This flag can only be used together with `enableViewRendererV2` with up to 20% faster render times.
     * - Warning: Rendering the view hiearchy using the `CALayer.render(in:)` method can lead to rendering issues, especially when using custom views.
     *            For complete rendering, it is recommended to set this option to `false`. In case you prefer performance over completeness, you can
     *            set this option to `true`.
     * - Experiment: This is an experimental feature and is therefore disabled by default. In case you are noticing issues with the experimental
     *               view renderer, please report the issue on [GitHub](https://github.com/getsentry/sentry-cocoa). Eventually, we will
     *               mark this feature as stable and remove the experimental flag, but will keep it disabled by default.
     *
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var enableFastViewRendering: Bool

    // MARK: - Masking

    /**
     * Indicates whether session replay should redact all non-bundled image
     * in the app by drawing a black rectangle over it.
     *
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var maskAllImages: Bool

    /**
     * Indicates whether session replay should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var maskAllText: Bool

    /**
     * A list of custom UIView subclasses that need
     * to be masked during session replay.
     * By default Sentry already mask text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     *
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var maskedViewClasses: [AnyClass]

    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the session replay.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `redactViewTypes`.
     *
     * - Note: See ``SentryScreenshotOptions.init`` for the default value.
     */
    public var unmaskedViewClasses: [AnyClass]

    /**
     * Initialize session replay options disabled
     *
     * - Note: This initializer is added for Objective-C compatibility, as constructors with default values
     *         are not supported in Objective-C.
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience override init() {
        // Setting all properties to nil will fallback to the default values in the init method.
        self.init(
            enableViewRendererV2: nil,
            enableFastViewRendering: nil,
            maskAllText: nil,
            maskAllImages: nil,
            maskedViewClasses: nil,
            unmaskedViewClasses: nil
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` using a dictionary.
     *
     * - Parameter dictionary: A dictionary containing the configuration options for the session replay.
     *
     * - Warning: This initializer is primarily used by Hybrid SDKs and is not intended for public use.
     */
    convenience init(dictionary: [String: Any]) {
        // This initalizer is calling the one with optional parameters, so that defaults can be applied
        // for absent values.
        self.init(
            enableViewRendererV2: (dictionary["enableViewRendererV2"] as? NSNumber)?.boolValue,
            enableFastViewRendering: (dictionary["enableFastViewRendering"] as? NSNumber)?.boolValue,
            maskAllText: (dictionary["maskAllText"] as? NSNumber)?.boolValue,
            maskAllImages: (dictionary["maskAllImages"] as? NSNumber)?.boolValue,
            maskedViewClasses: (dictionary["maskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }),
            unmaskedViewClasses: (dictionary["unmaskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            })
        )
    }

    /**
     * Initializes a new instance of ``SentryReplayOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - enableViewRendererV2: Enables the up to 5x faster view renderer.
     *   - enableFastViewRendering: Enables faster but incomplete view rendering. See ``SentryScreenshotOptions.enableFastViewRendering`` for more information.
     *   - maskAllText: Flag to redact all text in the app by drawing a rectangle over it.
     *   - maskAllImages: Flag to redact all images in the app by drawing a rectangle over it.
     *   - maskedViewClasses: A list of custom UIView subclasses that need to be masked during session replay.
     *   - unmaskedViewClasses: A list of custom UIView subclasses to be ignored during masking step of the session replay.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience init(
        enableViewRendererV2: Bool = DefaultValues.enableViewRendererV2,
        enableFastViewRendering: Bool = DefaultValues.enableFastViewRendering,
        maskAllText: Bool = DefaultValues.maskAllText,
        maskAllImages: Bool = DefaultValues.maskAllImages,
        maskedViewClasses: [AnyClass] = DefaultValues.maskedViewClasses,
        unmaskedViewClasses: [AnyClass] = DefaultValues.unmaskedViewClasses
    ) {
        // - This initializer is publicly available for Swift, but not for Objective-C, because automatically bridged Swift initializers
        //   with default values result in a single initializer requiring all parameters.
        // - Each parameter has a default value, so the parameter can be omitted, which is not possible for Objective-C.
        // - Parameter values are not optional, because SDK users should not be able to set them to nil.
        // - The publicly available property `quality` is omitted in this initializer, because adding it would break backwards compatibility
        //   with the automatically bridged Objective-C initializer.
        self.init(
            enableViewRendererV2: enableViewRendererV2,
            enableFastViewRendering: enableFastViewRendering,
            maskAllText: maskAllText,
            maskAllImages: maskAllImages,
            maskedViewClasses: maskedViewClasses,
            unmaskedViewClasses: unmaskedViewClasses,
        )
    }

    private init(
        enableViewRendererV2: Bool?,
        enableFastViewRendering: Bool?,
        maskAllText: Bool?,
        maskAllImages: Bool?,
        maskedViewClasses: [AnyClass]?,
        unmaskedViewClasses: [AnyClass]?
    ) {
        self.maskAllText = maskAllText ?? DefaultValues.maskAllText
        self.maskAllImages = maskAllImages ?? DefaultValues.maskAllImages
        self.enableViewRendererV2 = enableViewRendererV2 ?? DefaultValues.enableViewRendererV2
        self.enableFastViewRendering = enableFastViewRendering ?? DefaultValues.enableFastViewRendering
        self.maskedViewClasses = maskedViewClasses ?? DefaultValues.maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses ?? DefaultValues.unmaskedViewClasses

        super.init()
    }

    public override var description: String {
        return "SentryScreenshotOptions(enableViewRendererV2: \(enableViewRendererV2), enableFastViewRendering: \(enableFastViewRendering), maskAllText: \(maskAllText), maskAllImages: \(maskAllImages), maskedViewClasses: \(maskedViewClasses), unmaskedViewClasses: \(unmaskedViewClasses))"
    }
}
