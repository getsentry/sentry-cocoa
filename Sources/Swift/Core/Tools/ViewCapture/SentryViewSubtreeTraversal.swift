#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import UIKit

enum SentryViewSubtreeTraversal {
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
            result.insert("CameraUI.ChromeSwiftUIView")
        }
        #endif
        return result
    }

    static func isExcluded(
        _ view: UIView,
        excludedViewClassPatterns: Set<String>,
        includedViewClassPatterns: Set<String>
    ) -> Bool {
        // Use string descriptions instead of NSClassFromString or stored class objects to avoid
        // triggering Objective-C +initialize on UIKit classes.
        let viewTypeId = type(of: view).description()
        if includedViewClassPatterns.contains(viewTypeId) {
            return false
        }

        return excludedViewClassPatterns.contains { viewTypeId.contains($0) }
    }
}
#endif
#endif
