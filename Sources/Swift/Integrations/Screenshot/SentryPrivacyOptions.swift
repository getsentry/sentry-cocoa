#if SDK_V10
import Foundation

/// Shared masking and view traversal settings for session replay and screenshot attachments.
@objcMembers
public final class SentryPrivacyOptions: NSObject, SentryRedactOptions {
    /// Default privacy settings. Text and non-bundled images are masked by default.
    public final class DefaultValues {
        /// Text masking is enabled.
        public static let maskAllText: Bool = true
        /// Non-bundled image masking is enabled.
        public static let maskAllImages: Bool = true
        /// No additional view classes are masked.
        public static let maskedViewClasses: [AnyClass] = []
        /// No view classes are explicitly unmasked.
        public static let unmaskedViewClasses: [AnyClass] = []
        /// No additional view types are excluded from traversal.
        public static let excludedViewClasses: Set<String> = []
        /// No view types override the default traversal exclusions.
        public static let includedViewClasses: Set<String> = []
    }

    // MARK: - Masking
    
    /**
     * Indicates whether the capture should redact all non-bundled images
     * in the app by drawing a black rectangle over it.
     *
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default value.
     */
    public var maskAllImages: Bool
    
    /**
     * Indicates whether the capture should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default value.
     */
    public var maskAllText: Bool
    
    /**
     * A list of custom UIView subclasses that need
     * to be masked during the capture.
     * By default Sentry already masks text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     *
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default value.
     */
    public var maskedViewClasses: [AnyClass]
    
    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the capture.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `maskedViewClasses`.
     *
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default value.
     */
    public var unmaskedViewClasses: [AnyClass]

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
     * - Note: You should use the methods ``excludeViewTypeFromSubtreeTraversal(_:)`` and ``includeViewTypeInSubtreeTraversal(_:)``
     *         to add and remove view types, so you do not accidentally remove our defaults.
     * - Note: The final set of excluded view types is computed by `SentryViewSubtreeTraversal` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryViewSubtreeTraversal` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     */
    public private(set) var excludedViewClasses: Set<String>

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
     * - Note: You should use the methods ``excludeViewTypeFromSubtreeTraversal(_:)`` and ``includeViewTypeInSubtreeTraversal(_:)``
     *         to add and remove view types, so you do not accidentally remove our defaults.
     * - Note: The final set of excluded view types is computed by `SentryViewSubtreeTraversal` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryViewSubtreeTraversal` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+
     *         by calling ``includeViewTypeInSubtreeTraversal("CameraUI.ChromeSwiftUIView")``.
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches. For example,
     *         if "ChromeCameraUI" is excluded and "Camera" is included, "ChromeCameraUI" will still be excluded
     *         because "Camera" doesn't exactly match "ChromeCameraUI".
     */
    public private(set) var includedViewClasses: Set<String>
    
    /**
     * Adds a view type pattern to the excluded set, preventing matching views' subtrees from being traversed.
     *
     * - Parameter viewType: The view type identifier pattern (as a string) to exclude from subtree traversal.
     *                      Matching uses partial string containment: if a view's class name contains this string,
     *                      the subtree will be ignored. For example, "MyView" will match "MyApp.MyView",
     *                      "MyViewSubclass", etc.
     *
     * - Note: This method adds the pattern to `excludedViewClasses`, which is then combined with
     *         default excluded types (defined in `SentryViewSubtreeTraversal`) and filtered by `includedViewClasses`
     *         to produce the final set.
     */
    public func excludeViewTypeFromSubtreeTraversal(_ viewType: String) {
        excludedViewClasses.insert(viewType)
    }
    
    /**
     * Adds a view type to the included set, allowing its subtree to be traversed.
     *
     * - Parameter viewType: The view type identifier (as a string) to include in subtree traversal.
     *                      Must exactly match the result of `type(of: view).description()`.
     *                      For example, "MyApp.MyView" will only match exactly "MyApp.MyView".
     *
     * - Note: This method adds the view type to `includedViewClasses`, which filters the combined set
     *         of default excluded types (defined in `SentryViewSubtreeTraversal`) and `excludedViewClasses`.
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+.
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches.
     */
    public func includeViewTypeInSubtreeTraversal(_ viewType: String) {
        includedViewClasses.insert(viewType)
    }

    /**
     * Initializes privacy options with masking enabled.
     *
     * - Note: This initializer is added for Objective-C compatibility, as constructors with default values
     *         are not supported in Objective-C.
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default values of each parameter.
     */
    public convenience override init() {
        self.init(
            maskAllText: DefaultValues.maskAllText,
            maskAllImages: DefaultValues.maskAllImages,
            maskedViewClasses: DefaultValues.maskedViewClasses,
            unmaskedViewClasses: DefaultValues.unmaskedViewClasses,
            excludedViewClasses: DefaultValues.excludedViewClasses,
            includedViewClasses: DefaultValues.includedViewClasses
        )
    }
    
    /**
     * Initializes a new instance of ``SentryPrivacyOptions`` using a dictionary.
     *
     * - Parameter dictionary: A dictionary containing the configuration options for captures.
     *
     * - Warning: This initializer is primarily used by Hybrid SDKs and is not intended for public use.
     */
    convenience init(dictionary: [String: Any]) {
        self.init(
            maskAllText: (dictionary["maskAllText"] as? NSNumber)?.boolValue ?? DefaultValues.maskAllText,
            maskAllImages: (dictionary["maskAllImages"] as? NSNumber)?.boolValue ?? DefaultValues.maskAllImages,
            maskedViewClasses: (dictionary["maskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }) ?? DefaultValues.maskedViewClasses,
            unmaskedViewClasses: (dictionary["unmaskedViewClasses"] as? NSArray)?.compactMap({ element in
                NSClassFromString((element as? String) ?? "")
            }) ?? DefaultValues.unmaskedViewClasses,
            excludedViewClasses: (dictionary["excludedViewClasses"] as? [String]).map { Set($0) } ?? DefaultValues.excludedViewClasses,
            includedViewClasses: (dictionary["includedViewClasses"] as? [String]).map { Set($0) } ?? DefaultValues.includedViewClasses
        )
    }
    
    /**
     * Initializes a new instance of ``SentryPrivacyOptions`` with the specified parameters.
     *
     * - Parameters:
     *   - maskAllText: Flag to redact all text in the app by drawing a rectangle over it.
     *   - maskAllImages: Flag to redact all images in the app by drawing a rectangle over it.
     *   - maskedViewClasses: A list of custom UIView subclasses that need to be masked during captures.
     *   - unmaskedViewClasses: A list of custom UIView subclasses to be ignored during masking.
     *   - excludedViewClasses: A set of view type identifiers that should be excluded from subtree traversal.
     *   - includedViewClasses: A set of view type identifiers that should be included in subtree traversal.
     *
     * - Note: See ``SentryPrivacyOptions.DefaultValues`` for the default values of each parameter.
     */
    public init(
        maskAllText: Bool = DefaultValues.maskAllText,
        maskAllImages: Bool = DefaultValues.maskAllImages,
        maskedViewClasses: [AnyClass] = DefaultValues.maskedViewClasses,
        unmaskedViewClasses: [AnyClass] = DefaultValues.unmaskedViewClasses,
        excludedViewClasses: Set<String> = DefaultValues.excludedViewClasses,
        includedViewClasses: Set<String> = DefaultValues.includedViewClasses
    ) {
        // - This initializer is publicly available for Swift, but not for Objective-C, because automatically bridged Swift initializers
        //   with default values result in a single initializer requiring all parameters.
        // - Each parameter has a default value, so the parameter can be omitted, which is not possible for Objective-C.
        // - Parameter values are not optional, because SDK users should not be able to set them to nil.
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
        self.excludedViewClasses = excludedViewClasses
        self.includedViewClasses = includedViewClasses

        super.init()
    }
    
}
#endif // SDK_V10
