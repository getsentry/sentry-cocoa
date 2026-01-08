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
     * A set of view type identifier strings that should be excluded from subtree traversal.
     *
     * Views matching these types will have their subtrees skipped during redaction to avoid crashes
     * caused by traversing problematic view hierarchies (e.g., views that activate internal CoreAnimation
     * animations when their layers are accessed).
     *
     * Matching uses partial string containment: if a view's class name (from `type(of: view).description()`)
     * contains any of these strings, the subtree will be ignored. For example, "MyView" will match
     * "MyApp.MyView", "MyViewSubclass", "Some.MyView.Container", etc.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.excludedViewClasses`` for the default value.
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     */
    public let excludedViewClasses: Set<String>
    
    /**
     * A set of view type identifier strings that should be included in subtree traversal.
     *
     * View types exactly matching these strings will be removed from the excluded set, allowing their subtrees
     * to be traversed even if they would otherwise be excluded by default or via `excludedViewClasses`.
     *
     * Matching uses exact string matching: the view's class name (from `type(of: view).description()`)
     * must exactly equal one of these strings. For example, "MyApp.MyView" will only match exactly "MyApp.MyView",
     * not "MyApp.MyViewSubclass".
     *
     * - Note: See ``SentryReplayOptions.DefaultValues.includedViewClasses`` for the default value.
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches. For example,
     *         if "ChromeCameraUI" is excluded and "Camera" is included, "ChromeCameraUI" will still be excluded
     *         because "Camera" doesn't exactly match "ChromeCameraUI".
     */
    public let includedViewClasses: Set<String>
    
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
     *   - maskAllImages: Flag to redact all images in the app by drawing a rectangle over it.
     *   - maskedViewClasses: The classes of views to mask.
     *   - unmaskedViewClasses: The classes of views to exclude from masking.
     *   - excludedViewClasses: A set of view type identifiers that should be excluded from subtree traversal.
     *   - includedViewClasses: A set of view type identifiers that should be included in subtree traversal.
     *   - enableViewRendererV2: Enables the up to 5x faster view renderer.
     *
     * - Note: See ``SentryReplayOptions.DefaultValues`` for the default values of each parameter.
     */
    public init(
        maskAllText: Bool = SentryReplayOptions.DefaultValues.maskAllText,
        maskAllImages: Bool = SentryReplayOptions.DefaultValues.maskAllImages,
        maskedViewClasses: [AnyClass] = SentryReplayOptions.DefaultValues.maskedViewClasses,
        unmaskedViewClasses: [AnyClass] = SentryReplayOptions.DefaultValues.unmaskedViewClasses,
        excludedViewClasses: Set<String> = SentryReplayOptions.DefaultValues.excludedViewClasses,
        includedViewClasses: Set<String> = SentryReplayOptions.DefaultValues.includedViewClasses,
        enableViewRendererV2: Bool = SentryReplayOptions.DefaultValues.enableViewRendererV2
    ) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
        self.excludedViewClasses = excludedViewClasses
        self.includedViewClasses = includedViewClasses
        self.enableViewRendererV2 = enableViewRendererV2
    }
}

#endif
