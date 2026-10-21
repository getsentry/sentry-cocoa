#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

internal enum SentryChildTextExtractor {
    static let maximumTextLength = 64
    private static let maximumDepth = 3
    private static let maximumSiblings = 5
    private static let maximumVisitedViews = 30
    private static let maximumInspectedViews = 60

    static func extract(from view: UIView, redactBuilder: SentryUIRedactBuilder? = nil) -> String? {
        var remainingInspections = maximumInspectedViews
        var inspectedViews = Set<ObjectIdentifier>()
        let rootMasking = maskingDecision(
            for: view,
            redactBuilder: redactBuilder,
            remainingInspections: &remainingInspections,
            inspectedViews: &inspectedViews
        )
        guard rootMasking != .maskSubtree else { return nil }

        var parts = [String]()
        var remainingTextCharacters = maximumTextLength + 1
        if rootMasking == .unmasked, let text = labelText(from: view) {
            append(text, to: &parts, remainingTextCharacters: &remainingTextCharacters)
        }

        var remainingViews = maximumVisitedViews
        if remainingTextCharacters > 0, remainingInspections > 0 {
            collectText(
                from: view.subviews,
                depth: 1,
                excluding: [],
                excludingTexts: [],
                redactBuilder: redactBuilder,
                remainingViews: &remainingViews,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews,
                remainingTextCharacters: &remainingTextCharacters,
                parts: &parts
            )
        }

        let text = parts.joined(separator: " ")
        guard !text.isEmpty else { return nil }
        guard text.count > maximumTextLength else { return text }
        return String(text.prefix(maximumTextLength)) + "..."
    }

    private struct TraversalState {
        let excludedViews: Set<ObjectIdentifier>
        let excludedTexts: Set<String>
        let shouldTraverseSubviews: Bool
    }

    private static func collectText(
        from views: [UIView],
        depth: Int,
        excluding excludedViews: Set<ObjectIdentifier>,
        excludingTexts: Set<String>,
        redactBuilder: SentryUIRedactBuilder?,
        remainingViews: inout Int,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>,
        remainingTextCharacters: inout Int,
        parts: inout [String]
    ) {
        guard depth <= maximumDepth else { return }
        var visitedSiblings = 0
        for view in views {
            guard remainingTextCharacters > 0,
                  inspect(
                      view,
                      remainingInspections: &remainingInspections,
                      inspectedViews: &inspectedViews
                  ) else { return }
            if excludedViews.contains(ObjectIdentifier(view)) {
                continue
            }
            let masking = maskingDecision(
                for: view,
                redactBuilder: redactBuilder,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews
            )
            if masking == .maskSubtree {
                continue
            }
            guard visitedSiblings < maximumSiblings, remainingViews > 0 else { return }
            visitedSiblings += 1
            remainingViews -= 1

            let state = traversalState(
                for: view,
                masking: masking,
                excluding: excludedViews,
                excludingTexts: excludingTexts,
                redactBuilder: redactBuilder,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews,
                remainingTextCharacters: &remainingTextCharacters,
                parts: &parts
            )

            traverseSubviewsIfNeeded(
                of: view,
                state: state,
                depth: depth,
                redactBuilder: redactBuilder,
                remainingViews: &remainingViews,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews,
                remainingTextCharacters: &remainingTextCharacters,
                parts: &parts
            )
        }
    }

    private static func traverseSubviewsIfNeeded(
        of view: UIView,
        state: TraversalState,
        depth: Int,
        redactBuilder: SentryUIRedactBuilder?,
        remainingViews: inout Int,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>,
        remainingTextCharacters: inout Int,
        parts: inout [String]
    ) {
        guard state.shouldTraverseSubviews,
              depth < maximumDepth,
              remainingViews > 0,
              remainingInspections > 0,
              remainingTextCharacters > 0 else { return }
        collectText(
            from: view.subviews,
            depth: depth + 1,
            excluding: state.excludedViews,
            excludingTexts: state.excludedTexts,
            redactBuilder: redactBuilder,
            remainingViews: &remainingViews,
            remainingInspections: &remainingInspections,
            inspectedViews: &inspectedViews,
            remainingTextCharacters: &remainingTextCharacters,
            parts: &parts
        )
    }

    private static func traversalState(
        for view: UIView,
        masking: SentryUIRedactBuilder.TextExtractionMaskingDecision,
        excluding excludedViews: Set<ObjectIdentifier>,
        excludingTexts: Set<String>,
        redactBuilder: SentryUIRedactBuilder?,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>,
        remainingTextCharacters: inout Int,
        parts: inout [String]
    ) -> TraversalState {
        guard masking == .unmasked else {
            return TraversalState(
                excludedViews: excludedViews,
                excludedTexts: excludingTexts,
                shouldTraverseSubviews: true
            )
        }
        return collectText(
            from: view,
            excluding: excludedViews,
            excludingTexts: excludingTexts,
            redactBuilder: redactBuilder,
            remainingInspections: &remainingInspections,
            inspectedViews: &inspectedViews,
            remainingTextCharacters: &remainingTextCharacters,
            parts: &parts
        )
    }

    private static func collectText(
        from view: UIView,
        excluding excludedViews: Set<ObjectIdentifier>,
        excludingTexts: Set<String>,
        redactBuilder: SentryUIRedactBuilder?,
        remainingInspections: inout Int,
        inspectedViews: inout Set<ObjectIdentifier>,
        remainingTextCharacters: inout Int,
        parts: inout [String]
    ) -> TraversalState {
        var excludedViews = excludedViews
        var excludedTexts = excludingTexts
        var shouldTraverseSubviews = true

        if let button = view as? UIButton, let title = boundedTitle(from: button) {
            let titleLabel = button.titleLabel
            let titleIsMasked = isButtonTitleMasked(
                titleLabel ?? button,
                redactBuilder: redactBuilder,
                remainingInspections: &remainingInspections,
                inspectedViews: &inspectedViews
            )
            if titleIsMasked {
                shouldTraverseSubviews = false
            } else {
                append(title, to: &parts, remainingTextCharacters: &remainingTextCharacters)
                excludedTexts.insert(title)
            }
            if let titleLabel {
                excludedViews.insert(ObjectIdentifier(titleLabel))
            }
        } else if let text = labelText(from: view), !excludedTexts.contains(text) {
            append(text, to: &parts, remainingTextCharacters: &remainingTextCharacters)
        }

        return TraversalState(
            excludedViews: excludedViews,
            excludedTexts: excludedTexts,
            shouldTraverseSubviews: shouldTraverseSubviews
        )
    }

    private static func append(
        _ text: String,
        to parts: inout [String],
        remainingTextCharacters: inout Int
    ) {
        let separatorLength = parts.isEmpty ? 0 : 1
        guard remainingTextCharacters > separatorLength else {
            remainingTextCharacters = 0
            return
        }
        let text = String(text.prefix(remainingTextCharacters - separatorLength))
        guard !text.isEmpty else { return }
        parts.append(text)
        remainingTextCharacters -= separatorLength + text.count
    }

    private static func labelText(from view: UIView) -> String? {
        guard let text = (view as? UILabel)?.text else { return nil }
        return boundedText(text)
    }

}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
