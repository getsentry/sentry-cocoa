#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
import Sentry

public class PreviewRedactOptions: SentryRedactOptions {
    public let maskAllText: Bool
    public let maskAllImages: Bool
    public let maskedViewClasses: [AnyClass]
    public let unmaskedViewClasses: [AnyClass]
    public let enableViewRendererV2: Bool

/**
     * Initializes a new instance of ``PreviewRedactOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - maskAllText: Flag to redact all text in the app by drawing a black rectangle over it.
     *   - maskAllImages: Flag to redact all non-bundled image in the app by drawing a black rectangle over it.
     *   - maskedViewClasses: The classes of views to mask.
     *   - unmaskedViewClasses: The classes of views to exclude from masking.
     *   - enableViewRendererV2: Enables the up to 5x faster new view renderer used by the Session Replay integration.
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
