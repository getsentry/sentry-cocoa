import Foundation

/// Options for configuring what content should be redacted in session replays.
@objc
public protocol SentryRedactOptions {
    /// Whether all text content should be masked. Defaults to `true`.
    var maskAllText: Bool { get }
    /// Whether all images should be masked. Defaults to `true`.
    var maskAllImages: Bool { get }
    /// Additional view classes that should always be masked.
    var maskedViewClasses: [AnyClass] { get }
    /// View classes that should never be masked, overriding default masking behavior.
    var unmaskedViewClasses: [AnyClass] { get }
    /// A set of view type identifier strings that should be excluded from subtree traversal.
    ///
    /// Views matching these types will have their subtrees skipped during redaction to avoid crashes
    /// caused by traversing problematic view hierarchies.
    var excludedViewClasses: Set<String> { get }
    /// A set of view type identifier strings that should be included in subtree traversal.
    ///
    /// View types exactly matching these strings will be removed from the excluded set, allowing
    /// their subtrees to be traversed even if they would otherwise be excluded.
    var includedViewClasses: Set<String> { get }
}

// swiftlint:disable missing_docs
@objcMembers
@_spi(Private) public final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    public var maskAllText: Bool = true
    public var maskAllImages: Bool = true
    public var maskedViewClasses: [AnyClass] = []
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
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     */
    public var excludedViewClasses: Set<String> = []
    
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
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+.
     * - Note: Included patterns use exact matching (not partial) to prevent accidental matches. For example,
     *         if "ChromeCameraUI" is excluded and "Camera" is included, "ChromeCameraUI" will still be excluded
     *         because "Camera" doesn't exactly match "ChromeCameraUI".
     */
    public var includedViewClasses: Set<String> = []
}
// swiftlint:enable missing_docs
