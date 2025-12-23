import Foundation

@objc
public protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }
    var excludedViewClasses: Set<String> { get }
    var includedViewClasses: Set<String> { get }
}

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
     * View types matching these patterns will be removed from the excluded set, allowing their subtrees
     * to be traversed even if they would otherwise be excluded by default or via `excludedViewClasses`.
     *
     * Matching uses partial string containment: if a view's class name (from `type(of: view).description()`)
     * contains any of these strings, it will be removed from the excluded set. For example, "MyView" will
     * match "MyApp.MyView", "MyViewSubclass", etc.
     *
     * - Note: The final set of excluded view types is computed by `SentryUIRedactBuilder` using the formula:
     *         **Default View Classes + Excluded View Classes - Included View Classes**
     *         Default view classes are defined in `SentryUIRedactBuilder` (e.g., `CameraUI.ChromeSwiftUIView` on iOS 26+).
     *         For example, you can use this to re-enable traversal for `CameraUI.ChromeSwiftUIView` on iOS 26+.
     */
    public var includedViewClasses: Set<String> = []
}
