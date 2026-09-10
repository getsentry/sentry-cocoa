#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

internal enum SentryChildTextExtractor {
    private static let maximumTextLength = 64
    private static let maximumDepth = 3
    private static let maximumSiblings = 5
    private static let maximumVisitedViews = 30

    static func extract(from view: UIView) -> String? {
        var parts = [String]()
        var remainingViews = maximumVisitedViews
        collectText(
            from: view.subviews,
            depth: 1,
            excluding: [],
            excludingTexts: [],
            remainingViews: &remainingViews,
            parts: &parts
        )
        let text = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard text.count > maximumTextLength else { return text }
        return String(text.prefix(maximumTextLength)) + "..."
    }

    private static func collectText(
        from views: [UIView],
        depth: Int,
        excluding excludedViews: Set<ObjectIdentifier>,
        excludingTexts: Set<String>,
        remainingViews: inout Int,
        parts: inout [String]
    ) {
        guard depth <= maximumDepth else { return }
        var visitedSiblings = 0
        for view in views {
            guard remainingViews > 0 else { return }
            remainingViews -= 1
            if excludedViews.contains(ObjectIdentifier(view)) {
                continue
            }
            guard visitedSiblings < maximumSiblings else { break }
            visitedSiblings += 1

            var excludedViews = excludedViews
            var excludedTexts = excludingTexts
            if let button = view as? UIButton, let title = title(from: button) {
                parts.append(title)
                if let titleLabel = button.titleLabel {
                    excludedViews.insert(ObjectIdentifier(titleLabel))
                } else {
                    excludedTexts.insert(title)
                }
            } else if let text = (view as? UILabel)?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty,
                      !excludedTexts.contains(text) {
                parts.append(text)
            }

            collectText(
                from: view.subviews,
                depth: depth + 1,
                excluding: excludedViews,
                excludingTexts: excludedTexts,
                remainingViews: &remainingViews,
                parts: &parts
            )
        }
    }

    private static func title(from button: UIButton) -> String? {
        if let title = button.currentTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let title = button.currentAttributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if #available(iOS 15.0, tvOS 15.0, *) {
            if let title = button.configuration?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                return title
            }
            if let title = button.configuration?.attributedTitle {
                let text = String(title.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }
}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
