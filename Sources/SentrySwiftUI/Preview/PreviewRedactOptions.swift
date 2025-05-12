#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
import Sentry

/**
 * Redaction options for the session replay masking preview.
 *
 * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
 */
public class PreviewRedactOptions: SentryRedactOptions {
    /**
     * Flag to redact all text in the app by drawing a rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllText`` for the default value.
     */
    public let maskAllText: Bool

    /**
     * Flag to redact all images in the app by drawing a rectangle over it.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskAllImages`` for the default value.
     */
    public let maskAllImages: Bool

    /**
     * The classes of views to mask.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.maskedViewClasses`` for the default value.
     */
    public let maskedViewClasses: [AnyClass]
    
    /**
     * The classes of views to exclude from masking.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.unmaskedViewClasses`` for the default value.
     */
    public let unmaskedViewClasses: [AnyClass]
    
    /**
     * Enables the up to 5x faster view renderer.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.enableViewRendererV2`` for the default value.
     */
    public let enableViewRendererV2: Bool

    /**
     * Initializes a new instance of ``PreviewRedactOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - maskAllText: Flag to redact all text in the app by drawing a rectangle over it.
     *   - maskAllImages: Flag to redact all bundled images in the app by drawing a rectangle over it.
     *   - maskedViewClasses: The classes of views to mask.
     *   - unmaskedViewClasses: The classes of views to exclude from masking.
     *   - enableViewRendererV2: Enables the up to 5x faster view renderer.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public init(
        maskAllText: Bool = SentryReplayOptions.DefaultValues.maskAllText,
        maskAllImages: Bool = SentryReplayOptions.DefaultValues.maskAllImages,
        maskedViewClasses: [AnyClass] = SentryReplayOptions.DefaultValues.maskedViewClasses,
        unmaskedViewClasses: [AnyClass] = SentryReplayOptions.DefaultValues.unmaskedViewClasses,
        enableViewRendererV2: Bool = SentryReplayOptions.DefaultValues.enableViewRendererV2
    ) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
        self.enableViewRendererV2 = enableViewRendererV2
    }
}

#endif
