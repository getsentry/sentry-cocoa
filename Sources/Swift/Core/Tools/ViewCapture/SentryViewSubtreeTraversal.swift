#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import UIKit

// Centralizes subtree traversal and exclusion matching for redaction and capture activity checks.
//
// The final decision is computed at runtime using the formula:
//
//   Default View Classes + Excluded View Classes - Included View Classes
//
// SDK users can add exclusions via options.excludedViewClasses and remove defaults via options.includedViewClasses.
// Matching rules:
// - Excluded patterns use partial matching (contains): "MyView" matches "MyApp.MyView", "MyViewSubclass", etc.
// - Included patterns use exact matching (Set.contains): "MyViewSubclass" only matches exactly "MyViewSubclass"
//
// This prevents accidental matches where "ChromeCameraUI" is excluded but "Camera" is included from causing crashes.
enum SentryViewSubtreeTraversal {
    /// Class identifier for ``CameraUI.ChromeSwiftUIView``, if it exists.
    ///
    /// This class name is used to identify views of this class type during subtree exclusion.
    /// This workaround is specifically for Xcode 16 building for iOS 26 where accessing CameraUI.ModeLoupeLayer
    /// causes a crash due to unimplemented init(layer:) initializer.
    private static let cameraChromeSwiftUIViewClassPattern = "CameraUI.ChromeSwiftUIView"

    static func isExcluded(_ view: UIView, options: SentryRedactOptions) -> Bool {
        isExcluded(
            view,
            excludedViewClassPatterns: defaultExcludedViewClassPatterns.union(options.excludedViewClasses),
            includedViewClassPatterns: options.includedViewClasses
        )
    }

    @discardableResult
    static func traverse(_ view: UIView, options: SentryRedactOptions, _ visit: (UIView) -> Bool) -> Bool {
        traverse(
            view,
            excludedViewClassPatterns: defaultExcludedViewClassPatterns.union(options.excludedViewClasses),
            includedViewClassPatterns: options.includedViewClasses,
            visit
        )
    }

    @discardableResult
    private static func traverse(
        _ view: UIView,
        excludedViewClassPatterns: Set<String>,
        includedViewClassPatterns: Set<String>,
        _ visit: (UIView) -> Bool
    ) -> Bool {
        guard !isExcluded(
            view,
            excludedViewClassPatterns: excludedViewClassPatterns,
            includedViewClassPatterns: includedViewClassPatterns
        ) else {
            return false
        }

        if visit(view) {
            return true
        }

        return view.subviews.contains {
            traverse(
                $0,
                excludedViewClassPatterns: excludedViewClassPatterns,
                includedViewClassPatterns: includedViewClassPatterns,
                visit
            )
        }
    }

    static var defaultExcludedViewClassPatterns: Set<String> {
        var result: Set<String> = []
        #if os(iOS)
        if #available(iOS 26.0, *) {
            result.insert(cameraChromeSwiftUIViewClassPattern)
        }
        #endif
        return result
    }

    static func isExcluded(
        _ view: UIView,
        excludedViewClassPatterns: Set<String>,
        includedViewClassPatterns: Set<String>
    ) -> Bool {
        // We intentionally avoid using `NSClassFromString` or directly referencing class objects here,
        // because both approaches can trigger the Objective-C `+initialize` method on the class.
        // This has side effects and can cause crashes, especially when performed off the main thread
        // or with UIKit classes that expect to be initialized on the main thread.
        //
        // Instead, we use the string description of the type (i.e., `type(of: view).description()`)
        // for comparison. This is a safer, more "Swifty" approach that avoids the pitfalls of
        // class initialization side effects.
        //
        // We have previously encountered related issues:
        // - In EmergeTools' snapshotting code where using `NSClassFromString` led to crashes [1]
        // - In Sentry's own SubClassFinder where storing or accessing class objects on a background thread caused crashes due to `+initialize` being called on UIKit classes [2]
        //
        // [1] https://github.com/EmergeTools/SnapshotPreviews/blob/main/Sources/SnapshotPreviewsCore/View%2BSnapshot.swift#L248
        // [2] Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift
        let viewTypeId = type(of: view).description()

        // Check if the view type id is in the list of included view classes (exact matching).
        // If yes we can exit early as this list overrules other matchings.
        if includedViewClassPatterns.contains(viewTypeId) {
            // Matches included pattern exactly, so don't ignore subtree
            return false
        }

        // Check excluded patterns using partial matching, with overruling using the included patterns with exact matching.
        //
        // For example, excluding "ChromeCameraUI" will match "MyApp.ChromeCameraUI", "ChromeCameraUISubclass", etc.
        //
        // However, if "ChromeCameraUI" is excluded and "Camera" is included, "ChromeCameraUI" will
        // still be excluded because "Camera" doesn't exactly match "ChromeCameraUI".
        for pattern in excludedViewClassPatterns where viewTypeId.contains(pattern) {
            // Matches excluded but not exactly included, so ignore subtree
            return true
        }

        return false
    }
}
#endif
#endif
