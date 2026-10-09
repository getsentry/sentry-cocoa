#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

extension SentryChildTextExtractor {
    static func maskingDecision(
        for view: UIView,
        redactBuilder: SentryUIRedactBuilder?,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>
    ) -> SentryUIRedactBuilder.TextExtractionMaskingDecision {
        if let redactBuilder {
            return redactBuilder.textExtractionMaskingDecision(
                for: view,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews
            )
        }

        var currentView: UIView? = view
        while let current = currentView {
            guard inspect(
                current,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews
            ) else { return .maskSubtree }
            guard !current.isHidden,
                  current.alpha > 0.01,
                  current.layer.opacity > 0.01 else {
                return .maskSubtree
            }
            currentView = current.superview
        }
        return .unmasked
    }

    static func isButtonTitleMasked(
        _ titleSource: UIView,
        redactBuilder: SentryUIRedactBuilder?,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>
    ) -> Bool {
        guard inspect(
            titleSource,
            remainingInspections: &remainingInspections,
            inspectedViews: &inspectedViews
        ) else { return true }
        return maskingDecision(
            for: titleSource,
            redactBuilder: redactBuilder,
            remainingInspections: &remainingInspections,
            inspectedViews: &inspectedViews
        ).isMasked
    }

    static func inspect(
        _ view: UIView,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>
    ) -> Bool {
        let identifier = ObjectIdentifier(view)
        guard !inspectedViews.contains(identifier) else { return true }
        guard remainingInspections > 0 else { return false }
        remainingInspections -= 1
        inspectedViews.insert(identifier)
        return true
    }
}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
