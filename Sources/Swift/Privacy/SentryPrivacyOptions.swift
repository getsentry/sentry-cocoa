#if SDK_V10
import Foundation

/// Shared masking and view traversal settings for session replay and screenshot attachments.
public struct SentryPrivacyOptions: SentryRedactOptions {
    // MARK: - Masking
    
    /**
     * Indicates whether the capture should redact all non-bundled images
     * in the app by drawing a black rectangle over it.
     *
     * - Note: Defaults to `true`.
     */
    public var maskAllImages: Bool = true
    
    /**
     * Indicates whether the capture should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - Note: Defaults to `true`.
     */
    public var maskAllText: Bool = true
    
    /**
     * A list of custom UIView subclasses that need
     * to be masked during the capture.
     * By default Sentry already masks text and image elements from UIKit
     * Every child of a view that is redacted will also be redacted.
     *
     * - Note: Defaults to an empty array.
     */
    public var maskedViewClasses: [AnyClass] = []
    
    /**
     * A list of custom UIView subclasses to be ignored
     * during masking step of the capture.
     * The views of given classes will not be redacted but their children may be.
     * This property has precedence over `maskedViewClasses`.
     *
     * - Note: Defaults to an empty array.
     */
    public var unmaskedViewClasses: [AnyClass] = []

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
    public private(set) var excludedViewClasses: Set<String> = []

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
    public private(set) var includedViewClasses: Set<String> = []
    
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
    public mutating func excludeViewTypeFromSubtreeTraversal(_ viewType: String) {
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
    public mutating func includeViewTypeInSubtreeTraversal(_ viewType: String) {
        includedViewClasses.insert(viewType)
    }

    /// Initializes privacy options with text and image masking enabled.
    public init() {}

    /// Initializes privacy options from hybrid SDK configuration, preserving defaults for absent values.
    init(dictionary: [String: Any]) {
        self.init()

        if let maskAllText = (dictionary["maskAllText"] as? NSNumber)?.boolValue {
            self.maskAllText = maskAllText
        }
        if let maskAllImages = (dictionary["maskAllImages"] as? NSNumber)?.boolValue {
            self.maskAllImages = maskAllImages
        }
        if let maskedViewClasses = dictionary["maskedViewClasses"] as? NSArray {
            self.maskedViewClasses = maskedViewClasses.compactMap {
                NSClassFromString(($0 as? String) ?? "")
            }
        }
        if let unmaskedViewClasses = dictionary["unmaskedViewClasses"] as? NSArray {
            self.unmaskedViewClasses = unmaskedViewClasses.compactMap {
                NSClassFromString(($0 as? String) ?? "")
            }
        }
        if let excludedViewClasses = dictionary["excludedViewClasses"] as? [String] {
            self.excludedViewClasses = Set(excludedViewClasses)
        }
        if let includedViewClasses = dictionary["includedViewClasses"] as? [String] {
            self.includedViewClasses = Set(includedViewClasses)
        }
    }
}
#endif // SDK_V10
